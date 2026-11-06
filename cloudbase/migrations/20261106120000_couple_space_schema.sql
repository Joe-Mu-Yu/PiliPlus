CREATE TABLE public.couple_spaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '我们的小窝',
  member_a TEXT NOT NULL,
  member_b TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT couple_spaces_two_distinct_members CHECK (member_b IS NULL OR member_a <> member_b)
);
CREATE TABLE public.couple_space_moments (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES public.couple_spaces(id) ON DELETE CASCADE,
  author_id TEXT NOT NULL DEFAULT auth.uid(),
  caption TEXT NOT NULL DEFAULT '',
  photos JSONB NOT NULL DEFAULT '[]'::jsonb,
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT couple_space_moments_photos_array CHECK (jsonb_typeof(photos) = 'array')
);
CREATE TABLE public.couple_space_comments (
  id TEXT PRIMARY KEY,
  moment_id TEXT NOT NULL REFERENCES public.couple_space_moments(id) ON DELETE CASCADE,
  author_id TEXT NOT NULL DEFAULT auth.uid(),
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE public.couple_space_entries (
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES public.couple_spaces(id) ON DELETE CASCADE,
  author_id TEXT NOT NULL DEFAULT auth.uid(),
  entry_type TEXT NOT NULL CHECK (entry_type IN ('day', 'message', 'task', 'letter')),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX couple_space_moments_space_published_idx ON public.couple_space_moments(space_id, published_at DESC);
CREATE INDEX couple_space_comments_moment_created_idx ON public.couple_space_comments(moment_id, created_at);
CREATE INDEX couple_space_entries_space_type_updated_idx ON public.couple_space_entries(space_id, entry_type, updated_at DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.couple_spaces, public.couple_space_moments, public.couple_space_comments, public.couple_space_entries TO authenticated;
ALTER TABLE public.couple_spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.couple_space_moments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.couple_space_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.couple_space_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY couple_spaces_member_select ON public.couple_spaces FOR SELECT TO authenticated USING (auth.uid() = member_a OR auth.uid() = member_b);
CREATE POLICY couple_spaces_creator_insert ON public.couple_spaces FOR INSERT TO authenticated WITH CHECK (auth.uid() = member_a AND member_b IS NULL);
CREATE POLICY couple_spaces_member_update ON public.couple_spaces FOR UPDATE TO authenticated USING (auth.uid() = member_a OR auth.uid() = member_b) WITH CHECK (auth.uid() = member_a OR auth.uid() = member_b);
CREATE POLICY couple_space_moments_member_select ON public.couple_space_moments FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid())));
CREATE POLICY couple_space_moments_member_insert ON public.couple_space_moments FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid() AND EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid())));
CREATE POLICY couple_space_moments_member_update ON public.couple_space_moments FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid()))) WITH CHECK (EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid())));
CREATE POLICY couple_space_moments_member_delete ON public.couple_space_moments FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND s.member_a = auth.uid()));
CREATE POLICY couple_space_comments_member_select ON public.couple_space_comments FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.couple_space_moments m JOIN public.couple_spaces s ON s.id = m.space_id WHERE m.id = moment_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid())));
CREATE POLICY couple_space_comments_member_insert ON public.couple_space_comments FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid() AND EXISTS (SELECT 1 FROM public.couple_space_moments m JOIN public.couple_spaces s ON s.id = m.space_id WHERE m.id = moment_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid())));
CREATE POLICY couple_space_comments_member_update ON public.couple_space_comments FOR UPDATE TO authenticated USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
CREATE POLICY couple_space_comments_member_delete ON public.couple_space_comments FOR DELETE TO authenticated USING (author_id = auth.uid());
CREATE POLICY couple_space_entries_member_select ON public.couple_space_entries FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid())));
CREATE POLICY couple_space_entries_member_insert ON public.couple_space_entries FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid() AND EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid())));
CREATE POLICY couple_space_entries_member_update ON public.couple_space_entries FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid()))) WITH CHECK (EXISTS (SELECT 1 FROM public.couple_spaces s WHERE s.id = space_id AND (s.member_a = auth.uid() OR s.member_b = auth.uid())));
CREATE POLICY couple_space_entries_member_delete ON public.couple_space_entries FOR DELETE TO authenticated USING (author_id = auth.uid());
