import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const DOMAIN = "survey.local";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const url = Deno.env.get("SUPABASE_URL")!;
  const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: u } = await caller.auth.getUser();
  if (!u?.user) return json({ error: "Not signed in" }, 401);
  const { data: me } = await service.from("profiles").select("role,active").eq("id", u.user.id).maybeSingle();
  if (!me || me.role !== "admin" || !me.active) return json({ error: "Admins only" }, 403);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Bad JSON" }, 400); }
  const action = body.action;

  if (action === "list") {
    const { data: ps, error } = await service.from("profiles").select("id,full_name,role,active,created_at").order("created_at");
    if (error) return json({ error: error.message }, 500);
    const { data: au } = await service.auth.admin.listUsers({ perPage: 1000 });
    const em: Record<string, string> = {}; (au?.users ?? []).forEach((x) => { em[x.id] = x.email ?? ""; });
    return json({ users: (ps ?? []).map((p) => ({ ...p, login: (em[p.id] ?? "").replace("@" + DOMAIN, "") })) });
  }

  if (action === "create") {
    const name = String(body.full_name ?? "").trim();
    let login = String(body.login ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    if (!name || !login) return json({ error: "Name and username are required" }, 400);
    if (password.length < 8) return json({ error: "Password must be at least 8 characters" }, 400);
    if (!login.includes("@")) {
      if (!/^[a-z0-9._-]{3,30}$/.test(login)) return json({ error: "Username: 3-30 letters, numbers, dot, dash or underscore" }, 400);
      login = login + "@" + DOMAIN;
    }
    const { data, error } = await service.auth.admin.createUser({ email: login, password, email_confirm: true, user_metadata: { full_name: name } });
    if (error || !data.user) return json({ error: error?.message ?? "Could not create user" }, 400);
    const role = body.role === "admin" ? "admin" : "enumerator";
    const { error: pe } = await service.from("profiles").insert({ id: data.user.id, full_name: name, role, active: true });
    if (pe) { await service.auth.admin.deleteUser(data.user.id); return json({ error: pe.message }, 500); }
    return json({ ok: true, id: data.user.id });
  }

  if (action === "set_active") {
    const id = String(body.id ?? "");
    if (id === u.user.id) return json({ error: "You cannot disable your own account" }, 400);
    const active = !!body.active;
    const { error } = await service.from("profiles").update({ active }).eq("id", id);
    if (error) return json({ error: error.message }, 500);
    await service.auth.admin.updateUserById(id, { ban_duration: active ? "none" : "876000h" });
    return json({ ok: true });
  }

  if (action === "reset_password") {
    const password = String(body.password ?? "");
    if (password.length < 8) return json({ error: "Password must be at least 8 characters" }, 400);
    const { error } = await service.auth.admin.updateUserById(String(body.id ?? ""), { password });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  return json({ error: "Unknown action" }, 400);
});
