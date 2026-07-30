ALTER TABLE public.feedback_requests
  ADD COLUMN IF NOT EXISTS implementation_title TEXT,
  ADD COLUMN IF NOT EXISTS implementation_description TEXT,
  ADD COLUMN IF NOT EXISTS edited_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

ALTER TABLE public.feedback_requests
  DROP CONSTRAINT IF EXISTS feedback_requests_implementation_title_check,
  ADD CONSTRAINT feedback_requests_implementation_title_check
    CHECK (
      implementation_title IS NULL OR
      char_length(implementation_title) BETWEEN 1 AND 120
    ),
  DROP CONSTRAINT IF EXISTS feedback_requests_implementation_description_check,
  ADD CONSTRAINT feedback_requests_implementation_description_check
    CHECK (
      implementation_description IS NULL OR
      char_length(implementation_description) BETWEEN 1 AND 4000
    );
