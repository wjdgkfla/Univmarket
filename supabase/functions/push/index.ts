// Sends one notification to every device of its recipient through FCM v1.
// Called by the notifications insert trigger in
// supabase/migrations/*_push_notifications.sql with the Vault token that
// push_details checks; any other caller gets a 401.
//
// Needs the Edge Function secret FIREBASE_SERVICE_ACCOUNT: the JSON key from
// Firebase Console > Project settings > Service accounts > Generate new
// private key (kept as a secret rather than committed to the repo).
import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@^10";

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

const getAccessToken = (clientEmail: string, privateKey: string) =>
  new Promise<string>((resolve, reject) => {
    const jwt = new JWT({
      email: clientEmail,
      key: privateKey,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    jwt.authorize((err, tokens) =>
      err ? reject(err) : resolve(tokens!.access_token!)
    );
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const body = await req.json().catch(() => ({}));
  const { data: n, error } = await admin.rpc("push_details", {
    p_token: req.headers.get("x-push-token") ?? "",
    p_notification_id: String(body.notification_id ?? ""),
  });
  if (error) {
    return error.code === "42501"
      ? json({ error: "unauthorized" }, 401)
      : json({ error: "lookup failed" }, 500);
  }
  if (!n || n.tokens.length === 0) return json({ sent: 0 });

  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) return json({ error: "push not configured" }, 503);
  const account = JSON.parse(raw);
  const accessToken = await getAccessToken(
    account.client_email,
    account.private_key,
  );

  let sent = 0;
  const stale: string[] = [];
  await Promise.all(
    (n.tokens as string[]).map(async (token) => {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: n.title, body: n.body },
              data: { link: n.link ?? "", type: n.type },
              android: {
                priority: "high",
                // One notification per chat: a newer message replaces it.
                notification: { tag: n.link ?? undefined },
              },
              apns: {
                payload: { aps: { sound: "default", badge: n.unread } },
              },
            },
          }),
        },
      );
      if (res.ok) {
        sent++;
        return;
      }
      const err = await res.json().catch(() => ({}));
      // The app was uninstalled or the token rotated: stop sending to it.
      const code = err?.error?.details?.find((d: { errorCode?: string }) =>
        d.errorCode
      )?.errorCode;
      if (res.status === 404 || code === "UNREGISTERED") stale.push(token);
      else console.error("FCM send failed:", res.status, JSON.stringify(err));
    }),
  );
  if (stale.length) {
    await admin.from("device_push_tokens").delete().in("token", stale);
  }
  return json({ sent, removed: stale.length });
});
