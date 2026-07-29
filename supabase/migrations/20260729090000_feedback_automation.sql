-- Approval-based student feedback automation.
-- Safe to apply to the existing ai-biztraining Supabase project.

CREATE OR REPLACE FUNCTION public.is_company_admin(target_company_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND is_admin = TRUE
      AND company_id = target_company_id
  );
$$;

CREATE OR REPLACE FUNCTION public.can_admin_user(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles admin_profile
    JOIN public.profiles target_profile ON target_profile.id = target_user_id
    WHERE admin_profile.id = auth.uid()
      AND admin_profile.is_admin = TRUE
      AND admin_profile.company_id = target_profile.company_id
  );
$$;

REVOKE ALL ON FUNCTION public.is_company_admin(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_admin_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_company_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_admin_user(UUID) TO authenticated;

DROP POLICY IF EXISTS "admin read company profiles" ON public.profiles;
CREATE POLICY "admin read company profiles"
  ON public.profiles FOR SELECT
  USING (public.is_company_admin(profiles.company_id));

DROP POLICY IF EXISTS "admin read company surveys" ON public.survey_responses;
CREATE POLICY "admin read company surveys"
  ON public.survey_responses FOR SELECT
  USING (public.can_admin_user(survey_responses.user_id));

DROP POLICY IF EXISTS "admin read company progress" ON public.section_progress;
CREATE POLICY "admin read company progress"
  ON public.section_progress FOR SELECT
  USING (public.can_admin_user(section_progress.user_id));

DROP POLICY IF EXISTS "admin read company badges" ON public.user_badges;
CREATE POLICY "admin read company badges"
  ON public.user_badges FOR SELECT
  USING (public.can_admin_user(user_badges.user_id));

CREATE TABLE IF NOT EXISTS public.feedback_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id),
  company_id UUID NOT NULL REFERENCES public.companies(id),
  category TEXT NOT NULL CHECK (category IN ('bug', 'improvement', 'content')),
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  description TEXT NOT NULL CHECK (char_length(description) BETWEEN 1 AND 4000),
  page_url TEXT CHECK (page_url IS NULL OR char_length(page_url) <= 500),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'implementing', 'in_review', 'completed', 'rejected', 'failed')),
  admin_note TEXT CHECK (admin_note IS NULL OR char_length(admin_note) <= 1000),
  approved_by UUID REFERENCES public.profiles(id),
  approved_at TIMESTAMPTZ,
  pull_request_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS feedback_requests_company_status_created_idx
  ON public.feedback_requests(company_id, status, created_at DESC);

ALTER TABLE public.feedback_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own feedback read" ON public.feedback_requests;
CREATE POLICY "own feedback read"
  ON public.feedback_requests FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "admin read company feedback" ON public.feedback_requests;
CREATE POLICY "admin read company feedback"
  ON public.feedback_requests FOR SELECT
  USING (public.is_company_admin(feedback_requests.company_id));
