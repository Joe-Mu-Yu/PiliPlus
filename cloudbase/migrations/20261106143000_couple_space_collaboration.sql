BEGIN;

CREATE TABLE IF NOT EXISTS public.couple_space_state (
  space_id TEXT PRIMARY KEY REFERENCES public.couple_spaces(id) ON DELETE CASCADE,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  revision BIGINT NOT NULL DEFAULT 0,
  updated_by TEXT NOT NULL DEFAULT auth.uid(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.couple_space_invites (
  token TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES public.couple_spaces(id) ON DELETE CASCADE,
  created_by TEXT NOT NULL,
  consumed_by TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS couple_space_invites_space_idx
  ON public.couple_space_invites(space_id, expires_at DESC);

ALTER TABLE public.couple_space_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.couple_space_invites ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.couple_space_state FROM anon, authenticated;
REVOKE ALL ON public.couple_space_invites FROM anon, authenticated;
GRANT SELECT ON public.couple_space_state TO authenticated;

DROP POLICY IF EXISTS couple_space_state_member_select ON public.couple_space_state;
CREATE POLICY couple_space_state_member_select ON public.couple_space_state
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.couple_spaces s
      WHERE s.id = space_id
        AND auth.uid() IN (s.member_a, s.member_b)
    )
  );

DROP POLICY IF EXISTS couple_spaces_creator_insert ON public.couple_spaces;
DROP POLICY IF EXISTS couple_spaces_member_update ON public.couple_spaces;
REVOKE INSERT, UPDATE, DELETE ON public.couple_spaces FROM authenticated;
GRANT SELECT ON public.couple_spaces TO authenticated;

CREATE OR REPLACE FUNCTION public.create_couple_space(
  p_name TEXT,
  p_payload JSONB DEFAULT '{}'::jsonb
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_space_id TEXT := gen_random_uuid()::text;
  v_name TEXT := left(coalesce(nullif(btrim(p_name), ''), '我们的小窝'), 80);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.couple_spaces
    WHERE v_uid IN (member_a, member_b)
  ) THEN
    RAISE EXCEPTION 'USER_ALREADY_HAS_SPACE';
  END IF;

  INSERT INTO public.couple_spaces(id, name, member_a)
  VALUES (v_space_id, v_name, v_uid);
  INSERT INTO public.couple_space_state(space_id, payload, updated_by)
  VALUES (v_space_id, coalesce(p_payload, '{}'::jsonb), v_uid);

  RETURN jsonb_build_object(
    'id', v_space_id,
    'name', v_name,
    'member_a', v_uid,
    'member_b', NULL,
    'revision', 0,
    'payload', coalesce(p_payload, '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_couple_space_invite(
  p_space_id TEXT
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
    SELECT 1 FROM public.couple_spaces
    WHERE id = p_space_id
      AND v_uid IN (member_a, member_b)
  ) THEN
    RAISE EXCEPTION 'SPACE_ACCESS_DENIED';
  END IF;

  DELETE FROM public.couple_space_invites
  WHERE space_id = p_space_id
    AND (expires_at <= now() OR consumed_by IS NULL);
  INSERT INTO public.couple_space_invites(
    token, space_id, created_by, expires_at
  ) VALUES (
    v_token, p_space_id, v_uid, now() + interval '15 minutes'
  );
  RETURN v_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.join_couple_space(
  p_token TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_invite public.couple_space_invites%ROWTYPE;
  v_space public.couple_spaces%ROWTYPE;
  v_state public.couple_space_state%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.couple_spaces
    WHERE v_uid IN (member_a, member_b)
  ) THEN
    RAISE EXCEPTION 'USER_ALREADY_HAS_SPACE';
  END IF;

  SELECT * INTO v_invite
  FROM public.couple_space_invites
  WHERE token = upper(btrim(p_token))
  FOR UPDATE;
  IF NOT FOUND OR v_invite.consumed_by IS NOT NULL OR v_invite.expires_at <= now() THEN
    RAISE EXCEPTION 'INVITE_INVALID_OR_EXPIRED';
  END IF;

  UPDATE public.couple_spaces
  SET member_b = v_uid, updated_at = now()
  WHERE id = v_invite.space_id AND member_b IS NULL
  RETURNING * INTO v_space;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SPACE_ALREADY_PAIRED';
  END IF;

  UPDATE public.couple_space_invites
  SET consumed_by = v_uid
  WHERE token = v_invite.token;
  SELECT * INTO v_state FROM public.couple_space_state
  WHERE space_id = v_space.id;

  RETURN jsonb_build_object(
    'id', v_space.id,
    'name', v_space.name,
    'member_a', v_space.member_a,
    'member_b', v_space.member_b,
    'revision', v_state.revision,
    'payload', v_state.payload
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.save_couple_space_state(
  p_space_id TEXT,
  p_expected_revision BIGINT,
  p_payload JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_uid TEXT := auth.uid();
  v_state public.couple_space_state%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.couple_spaces
    WHERE id = p_space_id
      AND v_uid IN (member_a, member_b)
  ) THEN
    RAISE EXCEPTION 'SPACE_ACCESS_DENIED';
  END IF;

  UPDATE public.couple_space_state
  SET payload = p_payload,
      revision = revision + 1,
      updated_by = v_uid,
      updated_at = now()
  WHERE space_id = p_space_id
    AND revision = p_expected_revision
  RETURNING * INTO v_state;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'COUPLE_SPACE_CONFLICT';
  END IF;

  RETURN jsonb_build_object(
    'revision', v_state.revision,
    'payload', v_state.payload,
    'updated_at', v_state.updated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_couple_space(TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_couple_space_invite(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.join_couple_space(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_couple_space_state(TEXT, BIGINT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_couple_space(TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_couple_space_invite(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_couple_space(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_couple_space_state(TEXT, BIGINT, JSONB) TO authenticated;

DROP POLICY IF EXISTS couple_space_objects_read ON storage.objects;
DROP POLICY IF EXISTS couple_space_objects_insert ON storage.objects;
DROP POLICY IF EXISTS couple_space_objects_update ON storage.objects;
DROP POLICY IF EXISTS couple_space_objects_delete ON storage.objects;
CREATE POLICY couple_space_objects_read ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'couple-space'
    AND EXISTS (
      SELECT 1 FROM public.couple_spaces s
      WHERE s.id = (storage.foldername(storage.objects.name))[1]
        AND auth.uid() IN (s.member_a, s.member_b)
    )
  );
CREATE POLICY couple_space_objects_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'couple-space'
    AND EXISTS (
      SELECT 1 FROM public.couple_spaces s
      WHERE s.id = (storage.foldername(storage.objects.name))[1]
        AND auth.uid() IN (s.member_a, s.member_b)
    )
  );
CREATE POLICY couple_space_objects_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'couple-space'
    AND EXISTS (
      SELECT 1 FROM public.couple_spaces s
      WHERE s.id = (storage.foldername(storage.objects.name))[1]
        AND auth.uid() IN (s.member_a, s.member_b)
    )
  )
  WITH CHECK (
    bucket_id = 'couple-space'
    AND EXISTS (
      SELECT 1 FROM public.couple_spaces s
      WHERE s.id = (storage.foldername(storage.objects.name))[1]
        AND auth.uid() IN (s.member_a, s.member_b)
    )
  );
CREATE POLICY couple_space_objects_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'couple-space'
    AND EXISTS (
      SELECT 1 FROM public.couple_spaces s
      WHERE s.id = (storage.foldername(storage.objects.name))[1]
        AND auth.uid() IN (s.member_a, s.member_b)
    )
  );

COMMIT;
