import { corsHeaders, json } from "../_shared/http.ts";
import { adminClient, userClient } from "../_shared/clients.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const admin = adminClient();
  try {
    const authorization = request.headers.get("Authorization") || "";
    const accessToken = authorization.replace(/^Bearer\s+/i, "");
    if (!accessToken) return json({ error: "Unauthorized" }, 401);
    const userApi = userClient(authorization);
    const { data: { user }, error: authError } = await userApi.auth.getUser(accessToken);
    if (authError || !user) return json({ error: "Unauthorized" }, 401);

    const { data: approver, error: profileError } = await userApi.from("profiles")
      .select("is_admin, company_id").eq("id", user.id).single();
    if (profileError || !approver?.is_admin) return json({ error: "Admin only" }, 403);

    const body = await request.json();
    const id = String(body.id || "");
    const action = String(body.action || "");
    if (!id || !["approve", "reject"].includes(action)) return json({ error: "Invalid input" }, 400);

    const { data: item, error: itemError } = await admin.from("feedback_requests")
      .select("id, company_id, category, title, description, page_url, status")
      .eq("id", id).eq("company_id", approver.company_id).single();
    if (itemError || !item) return json({ error: "Not found" }, 404);
    if (!["pending", "failed"].includes(item.status)) return json({ error: "Already processed" }, 409);

    if (action === "reject") {
      const { error } = await admin.from("feedback_requests").update({
        status: "rejected", updated_at: new Date().toISOString(),
      }).eq("id", id).in("status", ["pending", "failed"]);
      if (error) throw error;
      return json({ ok: true, status: "rejected" });
    }

    const githubToken = Deno.env.get("GITHUB_TOKEN");
    const githubRepo = Deno.env.get("GITHUB_REPOSITORY");
    if (!githubToken || !githubRepo) return json({ error: "GitHub automation is not configured" }, 503);

    const { data: locked, error: lockError } = await admin.from("feedback_requests").update({
      status: "implementing",
      approved_by: user.id,
      approved_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq("id", id).in("status", ["pending", "failed"]).select("id").maybeSingle();
    if (lockError) throw lockError;
    if (!locked) return json({ error: "Already processed" }, 409);

    const dispatch = await fetch(`https://api.github.com/repos/${githubRepo}/actions/workflows/implement-feedback.yml/dispatches`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${githubToken}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        ref: "master",
        inputs: {
          feedback_id: item.id,
          category: item.category,
          title: item.title,
          description: item.description,
          page_url: item.page_url || "",
        },
      }),
    });
    if (!dispatch.ok) {
      console.error("GitHub dispatch failed", dispatch.status, await dispatch.text());
      await admin.from("feedback_requests").update({
        status: "failed", updated_at: new Date().toISOString(),
      }).eq("id", id);
      return json({ error: "GitHub automation could not be started" }, 502);
    }
    return json({ ok: true, status: "implementing" });
  } catch (error) {
    console.error(error);
    return json({ error: "Internal error" }, 500);
  }
});
