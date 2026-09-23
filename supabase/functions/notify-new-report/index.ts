// Emails moderators about a new report. Called by the reports insert trigger
// in supabase/migrations/*_report_email_alerts.sql with the Vault token that
// report_email_details checks; any other caller gets a 401.
//
// Sends through Gmail over SMTPS (port 465; Supabase blocks 25 and 587).
// Needs the Edge Function secret GMAIL_APP_PASSWORD: a Google App Password
// for GMAIL_USER (default univmarket.app@gmail.com), not the account password.
import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6";

const gmailUser = Deno.env.get("GMAIL_USER") ?? "univmarket.app@gmail.com";
const gmailPassword = Deno.env.get("GMAIL_APP_PASSWORD");

const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  secretKeys.default ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

// Keys match the reports.reason check constraint.
const reasons: Record<string, string> = {
  prohibited: "Prohibited or unsafe item",
  scam: "Scam or fraud",
  harassment: "Harassment or hate",
  spam: "Spam or misleading",
  other: "Something else",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  const token = req.headers.get("x-report-token") ?? "";
  const body = await req.json().catch(() => ({}));

  // A test send still needs the token: look up a report id that cannot
  // exist, which checks the token without touching real data.
  const reportId = body.test === true ? "" : String(body.report_id ?? "");
  const { data: report, error } = await admin.rpc("report_email_details", {
    p_token: token,
    p_report_id: reportId,
  });
  if (error) {
    return error.code === "42501"
      ? json({ error: "unauthorized" }, 401)
      : json({ error: "lookup failed" }, 500);
  }
  if (!gmailPassword) return json({ error: "email not configured" }, 503);

  const transport = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user: gmailUser, pass: gmailPassword },
  });

  const send = async (mail: Record<string, unknown>) => {
    try {
      await transport.sendMail({
        from: `"UnivMarket Reports" <${gmailUser}>`,
        ...mail,
      });
      return null;
    } catch (e) {
      // Usually a wrong or revoked App Password; visible in function logs.
      console.error("Gmail send failed:", e instanceof Error ? e.message : e);
      return json({ error: "send failed" }, 502);
    }
  };

  if (body.test === true) {
    const failed = await send({
      to: gmailUser,
      subject: "UnivMarket report alerts are working",
      text: "This is a test. New reports will be emailed to this inbox.",
    });
    return failed ?? json({ sent: true, test: true });
  }
  // Already resolved, or never existed: nothing to announce.
  if (!report) return json({ sent: false });

  const reason = reasons[report.reason] ?? report.reason;
  const lines = [
    `A student at ${report.school} filed a report.`,
    "",
    `Reason: ${reason}`,
    report.listing_title
      ? `Listing: ${report.listing_title}`
      : "About: the student (no listing)",
    `Reported student: ${report.reported_user_name}`,
    `Reported by: ${report.reporter_name}`,
    ...(report.notes ? [`Notes: ${report.notes}`] : []),
    "",
    "Review it in the UnivMarket app: Profile > Review reports.",
  ];
  const failed = await send({
    to: gmailUser,
    bcc: report.admin_emails,
    subject: `New report at ${report.school}: ${reason}`,
    text: lines.join("\n"),
  });
  return failed ??
    json({ sent: true, recipients: 1 + report.admin_emails.length });
});
