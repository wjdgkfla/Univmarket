# iPhone QA audit — September 20, 2026

Base: GitHub main `ad4075b` (includes the previous Claude fixes).

## Reproduced and fixed

- Inbox never fetched new conversations after bootstrap. It now refreshes on entry, every 15 seconds while mounted/foregrounded, and on app resume. Failed refreshes display Retry; refresh jobs are coalesced and timers are disposed.
- A committed message was reported as failed when the subsequent conversation read failed. The repository now caches the server-confirmed message ID and treats later refresh failures separately; rejected sends still fail without adding a message.
- A successful send erased a newer draft typed while the network request was pending. Only the unchanged submitted draft is cleared.
- Seller-profile network failures escaped an unawaited lookup as unhandled asynchronous errors. They now preserve the placeholder and allow later retries.
- Long conversations opened at the oldest message. The message list now anchors at the newest message while preserving chronological display.
- Search sorting overflowed narrow screens/large text. The control now uses the available width below the result count.
- Sell-form category/condition dropdowns overflowed narrow screens/large text. They now expand within the form width.
- Offer-card headers overflowed narrow screens/large text. Labels now wrap.

## Verification scope

The existing baseline suite passed 63 tests before this audit. Added regression coverage reproduces each fixed behavior. Layout scenarios visit Home, Search, Sell, Saved, Inbox, listing detail, chat, and Profile at 320×568 with 1.3× text and 390×844 with 2× text using Flutter's iOS target platform.

Repository tests exercise the actual repository and Supabase client with controlled HTTP responses. These do not create production accounts, send real messages, or modify the live database. Widget tests are not an iOS simulator or physical-device run.

## Still required before a public release

- Install the signed current build on an iPhone, confirming build identity rather than using the older installed app.
- With verified university accounts supplied by the owner, test email confirmation/recovery links from Mail and Safari, cold start, sign-out/relaunch, and university separation.
- Test the native photo picker, photo permission denial, upload failure/retry, keyboard dismissal, safe areas, VoiceOver, and background/resume on the device.
- Exercise two-user messaging/offers and listing state transitions against the backend, including connection loss during writes. An ambiguous network failure before a server acknowledgment can still require reconciling server state.
- Review account deletion, moderation/reporting, and transaction completion as release requirements; this bug-fix pass does not add those product flows.

No production migrations or Auth configuration changes are part of this patch. A passing suite is evidence for the covered cases, not proof that the application has no bugs.
