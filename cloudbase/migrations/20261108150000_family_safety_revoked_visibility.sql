BEGIN;

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
  WHERE (p_group_id IS NULL OR id = p_group_id)
    AND v_uid IN (care_recipient_id, caregiver_id)
  ORDER BY
    CASE status WHEN 'active' THEN 0 ELSE 1 END,
    created_at DESC
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
      AND v_group.status = 'active'
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

COMMIT;
