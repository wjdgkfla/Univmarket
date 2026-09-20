# iPhone QA audit — September 20, 2026

Base: GitHub main `ad4075b` (includes the previous Claude fixes).

## Reproduced and fixed

- Inbox never fetched new conversations after bootstrap. It now refreshes on entry, every 15 seconds while mounted/foregrounded, and on app resume. Failed refreshes display Retry; refresh jobs are coalesced and timers are disposed.
- A committed message was reported as failed when the subsequent conversation read failed. The repository now caches the server-confirmed message ID and treats later refresh failures separately; rejected sends still fail without adding a message.
- Overlapping inbox/chat snapshots could overwrite newer messages or offer receipts. Cache revisions reject stale snapshots and retry up to three reads, surfacing retryable failure if contention persists.
- A successful send erased a newer draft typed while the network request was pending. Only the unchanged submitted draft is cleared.
- Seller-profile network failures escaped an unawaited lookup as unhandled asynchronous errors. They now preserve the placeholder and allow later retries.
- Long conversations opened at the oldest message. The message list now anchors at the newest message while preserving chronological display.
- Search sorting overflowed narrow screens/large text. The control now uses the available width below the result count.
- Sell-form category/condition dropdowns overflowed narrow screens/large text. They now expand within the form width.
- Offer-card headers overflowed narrow screens/large text. Labels now wrap.
- Fresh signed-out installs now open a welcome screen with real sign-in and signup choices. Cached legacy school identities stay outside the marketplace.
- Signup omitted the native email redirect; signup and recovery now target the app callback. The live callback allowlist was empty and now contains the exact native URI.
- Auth branding overflowed at 2× text; it now wraps within available width.
- Non-login sample sellers are explicitly labeled, with bundled illustrative photos and disabled message/offer controls.

## Verification scope

The existing baseline suite passed 63 tests before this audit. Added regression coverage reproduces each fixed behavior. Layout scenarios visit Home, Search, Sell, Saved, Inbox, listing detail, chat, and Profile at 320×568 with 1.3× text and 390×844 with 2× text using Flutter's iOS target platform.

Repository tests exercise the actual repository and Supabase client with controlled HTTP responses. These do not create production accounts, send real messages, or modify the live database. Widget tests are not an iOS simulator or physical-device run.

## Still required before a public release

- Install the signed current build on an iPhone, confirming build identity rather than using the older installed app.
- With verified university accounts supplied by the owner, test email confirmation/recovery links from Mail and Safari, cold start, sign-out/relaunch, and university separation.
- Test the native photo picker, photo permission denial, upload failure/retry, keyboard dismissal, safe areas, VoiceOver, and background/resume on the device.
- Exercise two-user messaging/offers and listing state transitions against the backend, including connection loss during writes. An ambiguous network failure before a server acknowledgment can still require reconciling server state.
- Review account deletion, moderation/reporting, and transaction completion as release requirements; this bug-fix pass does not add those product flows.

## Owner-authorized live changes

- Removed eight enumerated legacy test auth users, their profiles, eight listings, one conversation/five messages/one offer, and dependent test data after a rollback-only rehearsal. No real university users or transactions existed among the cleanup targets. No in-app undo exists.
- Added two non-login sample seller profiles, with four listings each at GMU and GWU. GMU pickups: two Fenwick Library and two Johnson Center; GWU: four Gelman Library.
- Ran rollback-only live access verification: own-school visibility, cross-school isolation, rejected sample contact, and no anonymous access all passed. No temporary verification accounts were retained.
- Disabled anonymous sign-ins, retained mandatory email confirmation, and allowlisted `com.univmarket.app://auth-callback/`.
- No schema/RLS weakening or migrations. Cleanup and verification SQL are recorded under `supabase/operations/`, not auto-run during database rebuild.

## Validation and blockers

- Full local suite: 80 tests pass. First patch (`b5612af`) also passed GitHub quality, unsigned iOS release build, and Android APK build.
- Prepared confirmation/recovery HTML and a $0 pilot guide in `EMAIL_SETUP.md`. SMTP and professional templates are **not applied live**: owner-controlled sender setup is still required. No real confirmation/recovery email delivery has been claimed.
- App icons and logos remain deferred at the owner's request.

A passing suite is evidence for the covered cases, not proof that the application has no bugs.
