// Sends a push notification for one message. Called by the messages insert
// trigger in supabase/migrations/*_push_notifications.sql with the Vault
// token that push_notification_details checks; any other caller gets a 401.
//
// Delivers through Firebase Cloud Messaging, which routes to both iOS
// (APNs) and Android from one call. Needs the Edge Function secret
// FIREBASE_SERVICE_ACCOUNT: the JSON key for a Firebase service account
// with the "Firebase Cloud Messaging API" role, from Project Settings >
// Service Accounts > Generate new private key in the Firebase console.
// firebase-admin exchanges it for delivery tokens itself; nothing else here
// talks to Google.
import { createClient } from "npm:@supabase/supabase-js@2";
import { cert, getApps, initializeApp } from "npm:firebase-admin@12/app";
import { getMessaging } from "npm:firebase-admin@12/messaging";

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
  const serviceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!serviceAccount) return json({ error: "push not configured" }, 503);

  if (!getApps().length) {
    initializeApp({ credential: cert(JSON.parse(serviceAccount)) });
  }
  const messaging = getMessaging();

  const tokens = details.tokens as Array<{ platform: string; token: string }>;
  const results = await Promise.allSettled(
    tokens.map((t) =>
      messaging.send({
        token: t.token,
        notification: { title: details.title, body: details.body },
        data: { link: details.link },
        apns: { payload: { aps: { sound: "default" } } },
      })
    ),
  );

  // A token that's uninstalled or revoked fails forever otherwise; drop it
  // instead of retrying it on every future message.
  const dead: string[] = [];
  results.forEach((r, i) => {
    if (r.status === "rejected") {
      const code = (r.reason as { code?: string } | undefined)?.code ?? "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        dead.push(tokens[i].token);
      } else {
        console.error("Push send failed:", r.reason);
      }
    }
  });
  if (dead.length) {
    await admin.from("device_push_tokens").delete().in("token", dead);
  }

  const delivered = results.filter((r) => r.status === "fulfilled").length;
  return json({ sent: delivered > 0, delivered, attempted: results.length });
});
