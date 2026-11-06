BEGIN;

REVOKE ALL ON public.couple_space_moments FROM anon, authenticated;
REVOKE ALL ON public.couple_space_comments FROM anon, authenticated;
REVOKE ALL ON public.couple_space_entries FROM anon, authenticated;

DROP POLICY IF EXISTS couple_space_moments_member_select
  ON public.couple_space_moments;
DROP POLICY IF EXISTS couple_space_moments_member_insert
  ON public.couple_space_moments;
DROP POLICY IF EXISTS couple_space_moments_member_update
  ON public.couple_space_moments;
DROP POLICY IF EXISTS couple_space_moments_member_delete
  ON public.couple_space_moments;

DROP POLICY IF EXISTS couple_space_comments_member_select
  ON public.couple_space_comments;
DROP POLICY IF EXISTS couple_space_comments_member_insert
  ON public.couple_space_comments;
DROP POLICY IF EXISTS couple_space_comments_member_update
  ON public.couple_space_comments;
DROP POLICY IF EXISTS couple_space_comments_member_delete
  ON public.couple_space_comments;

DROP POLICY IF EXISTS couple_space_entries_member_select
  ON public.couple_space_entries;
DROP POLICY IF EXISTS couple_space_entries_member_insert
  ON public.couple_space_entries;
DROP POLICY IF EXISTS couple_space_entries_member_update
  ON public.couple_space_entries;
DROP POLICY IF EXISTS couple_space_entries_member_delete
  ON public.couple_space_entries;

COMMIT;
