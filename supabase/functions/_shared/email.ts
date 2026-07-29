type EmailInput = { subject: string; html: string };

export async function sendNotification(input: EmailInput) {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const to = Deno.env.get("NOTIFICATION_EMAIL");
  const from = Deno.env.get("NOTIFICATION_FROM");
  if (!apiKey || !to || !from) return { skipped: true };

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from, to: [to], subject: input.subject, html: input.html }),
  });
  if (!response.ok) throw new Error(`Email notification failed: ${response.status}`);
  return { skipped: false };
}

export function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
