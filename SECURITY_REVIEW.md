# Security review — feedback automation

Date: 2026-07-29

## Result

No unresolved high-severity findings were identified in the new feedback flow.

## Controls verified

- Feedback requires a valid Supabase user session.
- Submit and approval functions verify the bearer token with `auth.getUser()` inside the function; the gateway's legacy JWT check is intentionally disabled.
- Category and field lengths are validated again in the Edge Function.
- Browser clients cannot insert, approve, reject, or update automation state directly.
- Browser roles have only `SELECT` table privileges; write privileges are restricted to `service_role` and further checked by Edge Functions.
- Approval re-verifies `is_admin` and company membership server-side.
- Student-submitted title and description remain immutable source records; owner-edited implementation instructions are stored in separate columns.
- Owner-edited instructions are length-validated server-side and can be written only through the admin-checked approval function.
- A compare-and-update status transition prevents duplicate approvals.
- Service role, GitHub, OpenAI, Resend, and callback credentials remain server-side.
- The official Codex GitHub Action isolates the OpenAI credential behind its Responses API proxy.
- Callback updates require a dedicated secret and accept only known statuses and GitHub PR URLs.
- User text is rendered with `textContent`; notification HTML is escaped.
- The notification Issue is created only in the private implementation repository and marks its body as untrusted input.
- Owner-approved instructions define the implementation task but cannot override the workflow's security constraints; embedded URLs, commands, and quoted text remain untrusted.
- Codex runs with a workspace-write sandbox and no interactive elevation.
- The Codex Action drops sudo before model-controlled work and checkout credentials are not persisted.
- Automation creates a PR and cannot merge or deploy directly.
- Completion callbacks run only for merged `codex/feedback-<UUID>` branches or an explicit trusted dispatch.
- Third-party GitHub Actions and Codex CLI are pinned to reviewed versions.
- RLS admin checks use narrowly granted `SECURITY DEFINER` helpers with a fixed `search_path`.

## Deployment requirements

- Protect `master` and require pull requests before merging.
- Use a fine-grained GitHub token restricted to this repository.
- Use a long, random callback secret and rotate it if disclosed.
- Keep production deployment separate from the implementation workflow.
- Re-run the repository security review before production deployment.
