BEGIN;

REVOKE ALL ON FUNCTION public.create_couple_space(TEXT, JSONB) FROM anon;
REVOKE ALL ON FUNCTION public.create_couple_space_invite(TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.join_couple_space(TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.save_couple_space_state(TEXT, BIGINT, JSONB) FROM anon;

GRANT EXECUTE ON FUNCTION public.create_couple_space(TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_couple_space_invite(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_couple_space(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_couple_space_state(TEXT, BIGINT, JSONB) TO authenticated;

COMMIT;
