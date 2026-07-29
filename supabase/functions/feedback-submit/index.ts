import { corsHeaders, json } from "../_shared/http.ts";
import { adminClient, userClient } from "../_shared/clients.ts";
import { escapeHtml, sendNotification } from "../_shared/email.ts";

const allowedCategories = new Set(["bug", "improvement", "content"]);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = request.headers.get("Authorization") || "";
    const { data: { user }, error: authError } = await userClient(authorization).auth.getUser();
    if (authError || !user) return json({ error: "Unauthorized" }, 401);

    const body = await request.json();
    const category = String(body.category || "");
    const title = String(body.title || "").trim();
    const description = String(body.description || "").trim();
    const pageUrl = String(body.page_url || "").trim();
    if (!allowedCategories.has(category) || !title || title.length > 120 ||
        !description || description.length > 4000 || pageUrl.length > 500) {
      return json({ error: "Invalid input" }, 400);
    }

    const admin = adminClient();
    const { data: profile, error: profileError } = await admin
      .from("profiles").select("name, company_id").eq("id", user.id).single();
    if (profileError || !profile?.company_id) return json({ error: "Profile not found" }, 403);

    const { data: feedback, error: insertError } = await admin.from("feedback_requests")
      .insert({
        user_id: user.id,
        company_id: profile.company_id,
        category,
        title,
        description,
        page_url: pageUrl || null,
      })
      .select("id").single();
    if (insertError) throw insertError;

    const adminUrl = Deno.env.get("ADMIN_URL") || "";
    try {
      await sendNotification({
        subject: `【AI研修】新しい改善リクエスト: ${title}`,
        html: `<h2>新しい改善リクエスト</h2>
          <p><strong>投稿者:</strong> ${escapeHtml(profile.name)}</p>
          <p><strong>種類:</strong> ${escapeHtml(category)}</p>
          <p><strong>件名:</strong> ${escapeHtml(title)}</p>
          <p style="white-space:pre-wrap">${escapeHtml(description)}</p>
          ${adminUrl ? `<p><a href="${escapeHtml(adminUrl)}">管理画面で確認・承認する</a></p>` : ""}`,
      });
    } catch (error) {
      console.error("Notification failed", error);
    }
    return json({ ok: true, id: feedback.id }, 201);
  } catch (error) {
    console.error(error);
    return json({ error: "Internal error" }, 500);
  }
});
