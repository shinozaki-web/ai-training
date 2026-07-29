import { corsHeaders, json } from "../_shared/http.ts";
import { adminClient } from "../_shared/clients.ts";
import { escapeHtml, sendNotification } from "../_shared/email.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const expected = Deno.env.get("AUTOMATION_CALLBACK_SECRET") || "";
  const received = request.headers.get("x-automation-secret") || "";
  if (!expected || received !== expected) return json({ error: "Unauthorized" }, 401);

  try {
    const body = await request.json();
    const id = String(body.id || "");
    const status = String(body.status || "");
    const pullRequestUrl = String(body.pull_request_url || "");
    if (!id || !["in_review", "failed"].includes(status) ||
        (pullRequestUrl && !/^https:\/\/github\.com\/[^/]+\/[^/]+\/pull\/\d+$/.test(pullRequestUrl))) {
      return json({ error: "Invalid input" }, 400);
    }

    const admin = adminClient();
    const { data: item, error } = await admin.from("feedback_requests").update({
      status,
      pull_request_url: pullRequestUrl || null,
      updated_at: new Date().toISOString(),
    }).eq("id", id).eq("status", "implementing").select("title").maybeSingle();
    if (error) throw error;
    if (!item) return json({ error: "Not found or invalid state" }, 409);

    try {
      await sendNotification({
        subject: status === "in_review" ? `【AI研修】実装PRができました: ${item.title}` : `【AI研修】自動実装を確認してください: ${item.title}`,
        html: status === "in_review"
          ? `<h2>実装PRができました</h2><p>${escapeHtml(item.title)}</p><p><a href="${escapeHtml(pullRequestUrl)}">PRを確認する</a></p>`
          : `<h2>自動実装が完了しませんでした</h2><p>${escapeHtml(item.title)}</p><p>管理画面から再実行できます。</p>`,
      });
    } catch (notifyError) {
      console.error("Notification failed", notifyError);
    }
    return json({ ok: true });
  } catch (error) {
    console.error(error);
    return json({ error: "Internal error" }, 500);
  }
});
