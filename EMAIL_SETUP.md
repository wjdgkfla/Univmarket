# Email delivery without a paid service

## Current state (September 20, 2026)

- Supabase remains the only identity provider and database. Do not add Clerk.
- Confirm email is enabled; anonymous sign-ins are disabled.
- Native redirect allowlist includes `com.univmarket.app://auth-callback/`.
- Signup and password recovery request that native callback explicitly.
- Custom SMTP is not configured. Real GMU/GWU email delivery is **not yet verified**.
- The default Site URL remains localhost; a future hosted web build needs its real HTTPS URL configured separately before testing web email links.

Supabase's default mail sender only delivers to project team members, not arbitrary students. Do not invite students to the Supabase organization as a workaround.

## $0 pilot without owning a domain

Use a dedicated Gmail account controlled by the owner for a small, private pilot, subject to Google's account eligibility and sending limits. This is temporary testing infrastructure, not a public-launch delivery guarantee. Do not use a university-managed or personal primary mailbox for the sender.

1. Owner creates/selects the dedicated Gmail account, enables two-step verification, and creates an app password. Some Google accounts cannot create app passwords.
2. In Supabase Authentication → Emails → SMTP Settings, configure:
   - Sender email and SMTP username: the dedicated Gmail address.
   - Sender name: `UnivMarket`.
   - Host: `smtp.gmail.com`; port: `587` (TLS/STARTTLS).
   - SMTP password: the Google **app password**, entered privately by the owner in the dashboard, never in chat or this repository.
3. After saving SMTP, paste the templates below into Authentication → Emails.
4. Test delivery and spam-folder placement to one owner-controlled GMU address and one GWU address, then test recovery on the signed app. Stop if delivery is rejected; do not repeatedly send.

No credentials belong in Dart, compile-time defines, GitHub commits, or screenshots. Gmail sends with a Gmail address even when the display name is UnivMarket.

## Preferred later: Resend with an owned domain

Resend Free currently allows 3,000 transactional emails per month and 100 per day. A verified domain is required to send beyond the account owner's test address. The free plan does not provide ownership of a branded domain. If the owner already controls a domain, Resend is a better fit than Gmail for the pilot.

Use Supabase's custom SMTP integration, keep verification/reset tokens managed by Supabase, and disable link tracking for authentication emails. Stay on Free; do not enable paid overages or purchase a domain without owner approval.

## Templates (prepared, not applied live)

- Confirm signup subject: `Confirm your UnivMarket email`
  - Body: `supabase/templates/confirmation.html`
- Reset password subject: `Reset your UnivMarket password`
  - Body: `supabase/templates/recovery.html`

Preserve every `{{ .ConfirmationURL }}` variable. No invented support address, third-party images, tracking pixels, or marketing content is included. Test links must never contain real tokens in screenshots or source control. Browser previews cannot prove rendering/delivery in every email client.

Both templates were visually checked at phone width; confirmation was also checked at desktop width. Arial/Helvetica are deliberately retained as email-safe fonts despite the general web-design detector's font warning.

## Other recommended services

- Sentry: useful next for opt-in release crash diagnostics after the owner creates a Free project; scrub emails, tokens, chat/listing contents, and other private data. No SDK or account added in this patch.
- Cloudflare: optional later for DNS/web hosting; not required for the native app or a Gmail sender.
- PostHog: defer product analytics until basic flows work and privacy choices are defined.
- Upstash and Pinecone: no demonstrated cache/queue or vector-search requirement in this bug-fix scope; do not add them.

## References

- https://supabase.com/docs/guides/auth/auth-smtp
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://support.google.com/mail/answer/7104828
- https://support.google.com/mail/answer/185833
- https://resend.com/pricing
- https://resend.com/docs/knowledge-base/403-error-resend-dev-domain
