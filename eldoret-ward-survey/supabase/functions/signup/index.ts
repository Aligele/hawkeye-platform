// Public sign-up. Deploy with verify_jwt = false (the app's publishable key is not a JWT).
// Creates the account as pending and inactive: it cannot read or write anything until an admin approves it
// from Results > Admin: team logins (manage-users: approve / reject).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  let b: any;
  try { b = await req.json(); } catch { return json({ error: "Bad request" }, 400); }
  if (b.website) return json({ ok: true });                      // honeypot: bots fill this hidden field
  const name = String(b.full_name ?? "").trim().slice(0, 80);
  const email = String(b.email ?? "").trim().toLowerCase();
  const note = String(b.note ?? "").trim().slice(0, 200);
  const password = String(b.password ?? "");
  if (name.length < 3) return json({ error: "Enter your full name." }, 400);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 120) return json({ error: "Enter a valid email address." }, 400);
  if (password.length < 8) return json({ error: "Password must be at least 8 characters." }, 400);

  const service = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  // Flood guard: refuse when many requests are already waiting.
  const { count } = await service.from("profiles").select("id", { count: "exact", head: true }).eq("pending", true);
  if ((count ?? 0) >= 200) return json({ error: "Too many sign-ups are waiting. Ask the survey admin to clear them." }, 429);

  const { data, error } = await service.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: name } });
  if (error || !data.user) {
    const taken = /already|registered|exists/i.test(error?.message ?? "");
    return json({ error: taken ? "This email already has an account. Sign in, or ask the survey admin." : "Could not create the account." }, taken ? 409 : 400);
  }
  const { error: pe } = await service.from("profiles").insert({ id: data.user.id, full_name: name, role: "enumerator", active: false, pending: true, note: note || null });
  if (pe) { await service.auth.admin.deleteUser(data.user.id); return json({ error: "Could not create the account." }, 500); }
  return json({ ok: true });
});
