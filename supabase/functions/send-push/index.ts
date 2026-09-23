// Sends a push notification for one message. Called by the messages insert
// trigger in supabase/migrations/*_push_notifications.sql with the Vault
// token that push_notification_details checks; any other caller gets a 401.
//
// Delivers through Firebase Cloud Messaging's HTTP v1 API, which routes to
// both iOS (APNs) and Android from one call. Needs the Edge Function secret
// FIREBASE_SERVICE_ACCOUNT: the JSON key for a Firebase service account
// with the "Firebase Cloud Messaging API" role, from Project Settings >
// Service Accounts > Generate new private key in the Firebase console.
//
// Uses google-auth-library only for the OAuth token exchange, not the full
// firebase-admin SDK: it's a much smaller dependency for what's needed here
// (one bearer token, then a plain fetch to FCM's REST endpoint), and
// Supabase's own push-notification example uses the same pair for exactly
// that reason — firebase-admin is a heavy Node SDK with a history of
// Deno-compatibility issues in Edge Functions.
// https://supabase.com/docs/guides/functions/examples/push-notifications
import { createClient } from "npm:@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@10";

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
  const token = req.headers.get("x-push-token") ?? "";
  const body = await req.json().catch(() => ({}));
  const messageId = String(body.message_id ?? "");

  const { data: details, error } = await admin.rpc("push_notification_details", {
    p_token: token,
    p_message_id: messageId,
  });
  if (error) {
    return error.code === "42501"
      ? json({ error: "unauthorized" }, 401)
      : json({ error: "lookup failed" }, 500);
  }
  // No device, the category is off, or the message was rolled back —
  // nothing to send, and none of those are failures.
  if (!details) return json({ sent: false });

  // Read per request: a warm worker must pick up a secret set after it started.
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) return json({ error: "push not configured" }, 503);
  const { project_id, client_email, private_key } = JSON.parse(raw);

  const jwtClient = new JWT({
    email: client_email,
    key: private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const { access_token: accessToken } = await jwtClient.authorize();

  const tokens = details.tokens as Array<{ platform: string; token: string }>;
  const results = await Promise.allSettled(
    tokens.map(async (t) => {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: t.token,
              notification: { title: details.title, body: details.body },
              data: { link: details.link },
              apns: { payload: { aps: { sound: "default" } } },
            },
          }),
        },
      );
      const data = await res.json();
      if (!res.ok) throw { token: t.token, ...data };
      return data;
    }),
  );

  // A token that's uninstalled or revoked fails forever otherwise; drop it
  // instead of retrying it on every future message.
  const dead: string[] = [];
  results.forEach((r) => {
    if (r.status === "rejected") {
      const reason = r.reason as {
        token?: string;
        error?: { status?: string; details?: Array<{ errorCode?: string }> };
      };
      const errorCode = reason.error?.details?.find((d) => d.errorCode)
        ?.errorCode;
      if (errorCode === "UNREGISTERED" || errorCode === "INVALID_ARGUMENT") {
        if (reason.token) dead.push(reason.token);
      } else {
        console.error("Push send failed:", reason);
      }
    }
  });
  if (dead.length) {
    await admin.from("device_push_tokens").delete().in("token", dead);
  }

  const delivered = results.filter((r) => r.status === "fulfilled").length;
  return json({ sent: delivered > 0, delivered, attempted: results.length });
});
