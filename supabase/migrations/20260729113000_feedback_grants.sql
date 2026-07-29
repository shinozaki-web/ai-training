-- Base table privileges are required in addition to RLS policies.
-- Browser users can only read rows permitted by RLS. All writes stay in
-- authenticated Edge Functions using the service role.
GRANT SELECT ON TABLE public.feedback_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.feedback_requests TO service_role;
