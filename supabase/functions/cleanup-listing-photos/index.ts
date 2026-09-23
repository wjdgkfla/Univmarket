// Removes listing photos that no live listing uses, at least 24 hours after
// upload. Called nightly by the pg_cron job in
// supabase/migrations/*_listing_photo_cleanup.sql, which sends the Vault
// token that orphaned_listing_photos checks. Any other caller gets a 401.
import { createClient } from "npm:@supabase/supabase-js@2";

const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  secretKeys.default ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const { data: names, error } = await admin.rpc("orphaned_listing_photos", {
    p_token: req.headers.get("x-cleanup-token") ?? "",
    p_limit: 500,
  });
  if (error) {
    return error.code === "42501"
      ? json({ error: "unauthorized" }, 401)
      : json({ error: "lookup failed" }, 500);
  }

  let removed = 0;
  for (let i = 0; i < names.length; i += 100) {
    const { data, error } = await admin.storage
      .from("listing-images")
      .remove(names.slice(i, i + 100));
    if (error) return json({ removed, error: "remove failed" }, 500);
    removed += data.length;
  }
  return json({ removed });
});
