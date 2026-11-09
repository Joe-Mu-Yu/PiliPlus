BEGIN;

CREATE TABLE public.family_safety_groups (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '我的家庭',
  care_recipient_id TEXT NOT NULL,
  caregiver_id TEXT,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'revoked')),
  consent_version TEXT NOT NULL,
  recipient_consented_at TIMESTAMPTZ NOT NULL,
  caregiver_consented_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ,
  CONSTRAINT family_safety_distinct_members CHECK (
    caregiver_id IS NULL OR care_recipient_id <> caregiver_id
  )
);

CREATE UNIQUE INDEX family_safety_active_recipient_idx
  ON public.family_safety_groups(care_recipient_id)
  WHERE status = 'active';
CREATE UNIQUE INDEX family_safety_active_caregiver_idx
  ON public.family_safety_groups(caregiver_id)
  WHERE status = 'active' AND caregiver_id IS NOT NULL;

CREATE TABLE public.family_safety_invites (
  token TEXT PRIMARY KEY,
  group_id TEXT NOT NULL REFERENCES public.family_safety_groups(id)
    ON DELETE CASCADE,
  created_by TEXT NOT NULL,
  consumed_by TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX family_safety_invites_group_idx
  ON public.family_safety_invites(group_id, expires_at DESC);

CREATE TABLE public.family_safety_check_ins (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL REFERENCES public.family_safety_groups(id)
    ON DELETE CASCADE,
  requested_by TEXT NOT NULL,
  message TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'shared', 'declined', 'expired')),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  responded_at TIMESTAMPTZ
);

CREATE INDEX family_safety_check_ins_group_idx
  ON public.family_safety_check_ins(group_id, requested_at DESC);
CREATE UNIQUE INDEX family_safety_one_pending_request_idx
  ON public.family_safety_check_ins(group_id)
  WHERE status = 'pending';

CREATE TABLE public.family_safety_locations (
  group_id TEXT PRIMARY KEY REFERENCES public.family_safety_groups(id)
    ON DELETE CASCADE,
  check_in_id TEXT REFERENCES public.family_safety_check_ins(id)
    ON DELETE SET NULL,
  latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  accuracy_meters DOUBLE PRECISION NOT NULL
    CHECK (accuracy_meters >= 0 AND accuracy_meters <= 50000),
  captured_at TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE public.family_safety_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id TEXT NOT NULL REFERENCES public.family_safety_groups(id)
    ON DELETE CASCADE,
  actor_id TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (
    event_type IN (
      'group_created',
      'invite_created',
      'caregiver_joined',
      'check_in_requested',
      'location_shared',
      'check_in_declined',
      'location_viewed',
      'group_revoked'
    )
  ),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX family_safety_events_group_idx
  ON public.family_safety_events(group_id, created_at DESC);

ALTER TABLE public.family_safety_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_safety_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_safety_check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_safety_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_safety_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.family_safety_groups FROM anon, authenticated;
REVOKE ALL ON public.family_safety_invites FROM anon, authenticated;
REVOKE ALL ON public.family_safety_check_ins FROM anon, authenticated;
REVOKE ALL ON public.family_safety_locations FROM anon, authenticated;
REVOKE ALL ON public.family_safety_events FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.family_safety_events_id_seq
  FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_family_safety_group(
  p_name TEXT,
  p_consent_version TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_group public.family_safety_groups%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF nullif(btrim(p_consent_version), '') IS NULL THEN
    RAISE EXCEPTION 'CONSENT_REQUIRED';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.family_safety_groups
    WHERE status = 'active'
      AND v_uid IN (care_recipient_id, caregiver_id)
  ) THEN
    RAISE EXCEPTION 'USER_ALREADY_IN_FAMILY';
  END IF;

  INSERT INTO public.family_safety_groups(
    id,
    name,
    care_recipient_id,
    consent_version,
    recipient_consented_at
  ) VALUES (
    gen_random_uuid()::text,
    left(coalesce(nullif(btrim(p_name), ''), '我的家庭'), 80),
    v_uid,
    left(btrim(p_consent_version), 80),
    now()
  ) RETURNING * INTO v_group;

  INSERT INTO public.family_safety_events(
    group_id, actor_id, event_type
  ) VALUES (
    v_group.id, v_uid, 'group_created'
  );

  RETURN to_jsonb(v_group);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_family_safety_invite(
  p_group_id TEXT
) RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_token TEXT := upper(replace(gen_random_uuid()::text, '-', ''));
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.family_safety_groups
    WHERE id = p_group_id
      AND status = 'active'
      AND care_recipient_id = v_uid
      AND caregiver_id IS NULL
  ) THEN
    RAISE EXCEPTION 'INVITE_ACCESS_DENIED';
  END IF;

  DELETE FROM public.family_safety_invites
  WHERE group_id = p_group_id
    AND consumed_by IS NULL;

  INSERT INTO public.family_safety_invites(
    token, group_id, created_by, expires_at
  ) VALUES (
    v_token, p_group_id, v_uid, now() + interval '15 minutes'
  );

  INSERT INTO public.family_safety_events(
    group_id, actor_id, event_type
  ) VALUES (
    p_group_id, v_uid, 'invite_created'
  );

  RETURN v_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.join_family_safety_group(
  p_token TEXT,
  p_consent_version TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_invite public.family_safety_invites%ROWTYPE;
  v_group public.family_safety_groups%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF nullif(btrim(p_consent_version), '') IS NULL THEN
    RAISE EXCEPTION 'CONSENT_REQUIRED';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.family_safety_groups
    WHERE status = 'active'
      AND v_uid IN (care_recipient_id, caregiver_id)
  ) THEN
    RAISE EXCEPTION 'USER_ALREADY_IN_FAMILY';
  END IF;

  SELECT * INTO v_invite
  FROM public.family_safety_invites
  WHERE token = upper(btrim(p_token))
  FOR UPDATE;

  IF NOT FOUND
     OR v_invite.consumed_by IS NOT NULL
     OR v_invite.expires_at <= now() THEN
    RAISE EXCEPTION 'INVITE_INVALID_OR_EXPIRED';
  END IF;

  UPDATE public.family_safety_groups
  SET caregiver_id = v_uid,
      caregiver_consented_at = now(),
      consent_version = left(btrim(p_consent_version), 80),
      updated_at = now()
  WHERE id = v_invite.group_id
    AND status = 'active'
    AND caregiver_id IS NULL
  RETURNING * INTO v_group;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAMILY_ALREADY_PAIRED';
  END IF;

  UPDATE public.family_safety_invites
  SET consumed_by = v_uid
  WHERE token = v_invite.token;

  INSERT INTO public.family_safety_events(
    group_id, actor_id, event_type
  ) VALUES (
    v_group.id, v_uid, 'caregiver_joined'
  );

  RETURN to_jsonb(v_group);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_family_safety_snapshot(
  p_group_id TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_group public.family_safety_groups%ROWTYPE;
  v_request JSONB;
  v_location JSONB;
  v_events JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  UPDATE public.family_safety_check_ins r
  SET status = 'expired'
  FROM public.family_safety_groups g
  WHERE r.group_id = g.id
    AND r.status = 'pending'
    AND r.expires_at <= now()
    AND v_uid IN (g.care_recipient_id, g.caregiver_id);

  SELECT * INTO v_group
  FROM public.family_safety_groups
  WHERE status = 'active'
    AND (p_group_id IS NULL OR id = p_group_id)
    AND v_uid IN (care_recipient_id, caregiver_id)
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT to_jsonb(request_row) INTO v_request
  FROM (
    SELECT id, group_id, requested_by, message, status,
           requested_at, expires_at, responded_at
    FROM public.family_safety_check_ins
    WHERE group_id = v_group.id
    ORDER BY requested_at DESC
    LIMIT 1
  ) request_row;

  SELECT to_jsonb(location_row) INTO v_location
  FROM (
    SELECT group_id, check_in_id, latitude, longitude, accuracy_meters,
           captured_at, received_at, expires_at
    FROM public.family_safety_locations
    WHERE group_id = v_group.id
      AND expires_at > now()
  ) location_row;

  IF v_location IS NOT NULL AND v_uid = v_group.caregiver_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.family_safety_events
      WHERE group_id = v_group.id
        AND actor_id = v_uid
        AND event_type = 'location_viewed'
        AND created_at > now() - interval '5 minutes'
    ) THEN
      INSERT INTO public.family_safety_events(
        group_id, actor_id, event_type
      ) VALUES (
        v_group.id, v_uid, 'location_viewed'
      );
    END IF;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(event_row)), '[]'::jsonb)
  INTO v_events
  FROM (
    SELECT id, actor_id, event_type, metadata, created_at
    FROM public.family_safety_events
    WHERE group_id = v_group.id
    ORDER BY created_at DESC
    LIMIT 20
  ) event_row;

  RETURN jsonb_build_object(
    'group', to_jsonb(v_group),
    'latest_request', v_request,
    'latest_location', v_location,
    'events', v_events,
    'current_user_id', v_uid
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.request_family_check_in(
  p_group_id TEXT,
  p_message TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_request public.family_safety_check_ins%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.family_safety_groups
    WHERE id = p_group_id
      AND status = 'active'
      AND caregiver_id = v_uid
  ) THEN
    RAISE EXCEPTION 'CAREGIVER_ACCESS_REQUIRED';
  END IF;

  UPDATE public.family_safety_check_ins
  SET status = 'expired'
  WHERE group_id = p_group_id
    AND status = 'pending'
    AND expires_at <= now();

  IF EXISTS (
    SELECT 1 FROM public.family_safety_check_ins
    WHERE group_id = p_group_id
      AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'CHECK_IN_ALREADY_PENDING';
  END IF;

  INSERT INTO public.family_safety_check_ins(
    id, group_id, requested_by, message, expires_at
  ) VALUES (
    gen_random_uuid()::text,
    p_group_id,
    v_uid,
    left(coalesce(btrim(p_message), ''), 120),
    now() + interval '30 minutes'
  ) RETURNING * INTO v_request;

  INSERT INTO public.family_safety_events(
    group_id, actor_id, event_type,
    metadata
  ) VALUES (
    p_group_id,
    v_uid,
    'check_in_requested',
    jsonb_build_object('request_id', v_request.id)
  );

  RETURN to_jsonb(v_request);
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_family_check_in(
  p_request_id TEXT,
  p_action TEXT,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_accuracy_meters DOUBLE PRECISION DEFAULT NULL,
  p_captured_at TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_request public.family_safety_check_ins%ROWTYPE;
  v_group public.family_safety_groups%ROWTYPE;
  v_location public.family_safety_locations%ROWTYPE;
BEGIN
  IF p_action NOT IN ('share', 'decline') THEN
    RAISE EXCEPTION 'INVALID_CHECK_IN_ACTION';
  END IF;

  SELECT * INTO v_request
  FROM public.family_safety_check_ins
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_request.status <> 'pending' THEN
    RAISE EXCEPTION 'CHECK_IN_NOT_PENDING';
  END IF;
  IF v_request.expires_at <= now() THEN
    UPDATE public.family_safety_check_ins
    SET status = 'expired'
    WHERE id = p_request_id;
    RAISE EXCEPTION 'CHECK_IN_EXPIRED';
  END IF;

  SELECT * INTO v_group
  FROM public.family_safety_groups
  WHERE id = v_request.group_id
    AND status = 'active'
    AND care_recipient_id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'RECIPIENT_ACCESS_REQUIRED';
  END IF;

  IF p_action = 'decline' THEN
    UPDATE public.family_safety_check_ins
    SET status = 'declined', responded_at = now()
    WHERE id = p_request_id;
    INSERT INTO public.family_safety_events(
      group_id, actor_id, event_type,
      metadata
    ) VALUES (
      v_group.id,
      v_uid,
      'check_in_declined',
      jsonb_build_object('request_id', p_request_id)
    );
    RETURN jsonb_build_object('status', 'declined');
  END IF;

  IF p_latitude IS NULL
     OR p_longitude IS NULL
     OR p_accuracy_meters IS NULL
     OR p_captured_at IS NULL THEN
    RAISE EXCEPTION 'LOCATION_REQUIRED';
  END IF;
  IF p_latitude NOT BETWEEN -90 AND 90
     OR p_longitude NOT BETWEEN -180 AND 180
     OR p_accuracy_meters NOT BETWEEN 0 AND 50000 THEN
    RAISE EXCEPTION 'LOCATION_INVALID';
  END IF;
  IF p_captured_at > now() + interval '5 minutes'
     OR p_captured_at < now() - interval '24 hours' THEN
    RAISE EXCEPTION 'LOCATION_TIMESTAMP_INVALID';
  END IF;

  INSERT INTO public.family_safety_locations(
    group_id,
    check_in_id,
    latitude,
    longitude,
    accuracy_meters,
    captured_at,
    expires_at
  ) VALUES (
    v_group.id,
    p_request_id,
    p_latitude,
    p_longitude,
    p_accuracy_meters,
    p_captured_at,
    now() + interval '24 hours'
  )
  ON CONFLICT (group_id) DO UPDATE SET
    check_in_id = EXCLUDED.check_in_id,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    accuracy_meters = EXCLUDED.accuracy_meters,
    captured_at = EXCLUDED.captured_at,
    received_at = now(),
    expires_at = EXCLUDED.expires_at
  RETURNING * INTO v_location;

  UPDATE public.family_safety_check_ins
  SET status = 'shared', responded_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.family_safety_events(
    group_id, actor_id, event_type,
    metadata
  ) VALUES (
    v_group.id,
    v_uid,
    'location_shared',
    jsonb_build_object('request_id', p_request_id)
  );

  RETURN to_jsonb(v_location);
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_family_safety_group(
  p_group_id TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.family_safety_groups
    WHERE id = p_group_id
      AND status = 'active'
      AND v_uid IN (care_recipient_id, caregiver_id)
  ) THEN
    RAISE EXCEPTION 'FAMILY_ACCESS_DENIED';
  END IF;

  INSERT INTO public.family_safety_events(
    group_id, actor_id, event_type
  ) VALUES (
    p_group_id, v_uid, 'group_revoked'
  );

  UPDATE public.family_safety_groups
  SET status = 'revoked', revoked_at = now(), updated_at = now()
  WHERE id = p_group_id;
  UPDATE public.family_safety_check_ins
  SET status = 'expired'
  WHERE group_id = p_group_id AND status = 'pending';
  DELETE FROM public.family_safety_locations WHERE group_id = p_group_id;
  DELETE FROM public.family_safety_invites WHERE group_id = p_group_id;
  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_family_safety_group(
  p_group_id TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.family_safety_groups
    WHERE id = p_group_id
      AND v_uid IN (care_recipient_id, caregiver_id)
  ) THEN
    RAISE EXCEPTION 'FAMILY_ACCESS_DENIED';
  END IF;
  DELETE FROM public.family_safety_groups WHERE id = p_group_id;
  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.create_family_safety_group(TEXT, TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_family_safety_invite(TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_family_safety_group(TEXT, TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_family_safety_snapshot(TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.request_family_check_in(TEXT, TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_family_check_in(
  TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TIMESTAMPTZ
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.revoke_family_safety_group(TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_family_safety_group(TEXT)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_family_safety_group(TEXT, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_family_safety_invite(TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_family_safety_group(TEXT, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_family_safety_snapshot(TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_family_check_in(TEXT, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_family_check_in(
  TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TIMESTAMPTZ
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_family_safety_group(TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_family_safety_group(TEXT)
  TO authenticated;

COMMIT;
