# Release progress — September 9, 2026

Branch: codex/deployment-readiness. The deployment goal remains active and incomplete.

Completed in this pass:
- Android release signing now uses private android/key.properties with no debug fallback. Native compilation/signing is still unverified.
- Supabase client configuration rejects insecure URLs, embedded credentials, missing keys and secret/legacy tokens. Errors do not echo keys.
- Supabase initialization is idempotent after success, allowing startup retries without reinitializing the SDK.
- 13 Flutter tests passed; flutter analyze --no-pub reports no issues.
- flutter doctor -v confirms the Android SDK is missing, no physical mobile devices are connected, and this host is Windows.

Backend audit evidence:
- BACKEND_SCHEMA_SNAPSHOT.json records the existing public functions and public/storage policies before migrations; it is an inspection snapshot, not a migration or backup.
- Seven auth users and seven profiles already exist; preserve records.
- Only the Fenwick university/domain seed exists. No storage buckets exist.
- No custom public-schema triggers were found.
- Client roles have broad table grants, including profile INSERT/UPDATE and TRUNCATE. Profile row policies only enforce ownership, so privileged fields require protection.
- public_profiles uses security_invoker=true, but its current underlying profile SELECT policy only exposes the current user's row.
- ensure_profile assigns Fenwick without university verification.
- start_conversation is SECURITY DEFINER and checks active status/blocking but not the listing's university membership.

Next work:
1. Generate versioned backend migrations and regression tests that revoke unnecessary table privileges, protect profile identity/role/state/university, and enforce confirmed-email membership.
2. Replace anonymous bootstrap with a real authentication/session flow and remove Fenwick constants.
3. Complete and test live repository writes, storage and private conversations/atomic offers, then launch-essential trust flows and native builds.

Do not treat these tests or configuration changes as evidence of live multi-user release readiness. See RELEASE_WORK_PLAN.md for the full remaining scope.

## Authentication and privilege migration progress

The app now has explicit sign-in and registration UI, a confirmed-account gate, and sign-out. Anonymous auto-login was removed. The repository cache is replaced on account changes; callbacks from disposed repositories no longer notify listeners. Registration presents an email-confirmation instruction. Password recovery, account deletion, secure native session storage, and real university authorization remain incomplete.

15 offline tests passed, including form validation, normalized email submission, generic retryable error handling, and registration confirmation messaging. These tests use a fake authentication service and do not prove live email delivery or end-to-end session behavior.

The hosted privilege regression test reproduced permission to update protected profile fields. The migration at supabase/migrations/20260909065021_protect_profile_privileges.sql and test at supabase/tests/profile_privileges.sql are saved but NOT applied. Automatic approval review rejected the broad privilege change because it could break existing behavior. An explicit approval question is pending. Do not execute the same migration through another tool or split it to evade that rejection.

Until approved and applied, the hosted profile privileges remain vulnerable. The existing Fenwick assignment and other RPC authorization gaps also remain. No live accounts or emails were created/sent during this work.

Live-mode web compilation passed with --dart-define-from-file=config/supabase.dev.json --output=build/live. The standard demo preview output was preserved. Flutter analysis passed after two brace-style fixes. Native builds remain untested.

## Campus-scoped live reads

The live repository now derives university and campus from the server profile. It validates that the assigned campus belongs to that active university, restricts pickup zones to that campus, and adds the university filter to the listing query. Missing assignments fail startup instead of silently choosing Fenwick. Listing university/status/cover photo are retained; HTTPS photos render as network images with an error fallback.

The repository accepts an injected Supabase client and exposes an initialization Future. SDK-level tests use a mock HTTP transport, not the hosted database: they verify actual generated request parameters, profile-based school naming, listing metadata, and zero backend requests for signed-out access. 18 total tests passed and analysis reports no issues.

These client filters are not server authorization. The hosted profile RPC still assigns Fenwick and its privileges remain unchanged while explicit migration approval is pending. Native deployment and the full release goal remain incomplete.

## Password recovery implementation

Added reset-email request and new-password forms, confirmation/minimum-length validation, neutral email response, generic retryable errors, and explicit sign-out after recovery. Android/iOS callback schemes are registered. LiveAuthGate owns initial/resumed callback parsing, validates sessions through Supabase, and prevents marketplace bootstrap during recovery. Supabase automatic URI detection is disabled to prevent consuming the same callback twice.

22 tests pass, including cold-start recovery with the real SDK plus isolated HTTP responses, expired-link handling, and recovery form validation/retry. The callback test initially stalled during SDK isolate disposal under fake time; SDK construction and disposal now run outside the widget test's simulated clock. Flutter analysis is clean. The live-mode web build succeeded. Native XML parses successfully.

AUTH_SETUP.md records required hosted redirect allowlisting and email configuration. No hosted settings were changed and no recovery emails were sent. Real-device email/deep-link verification, secure native token persistence, account deletion, verified university membership, the blocked privilege migration, and the remaining marketplace/release gates are still outstanding.

## Recovery link review follow-up
- Fixed startup subscription ordering so account links arriving during initial lookup are retained.
- Failed callback exchanges are retryable; only successful callbacks are deduplicated.
- Both regression tests were observed failing against the previous behavior and passing after fixes. Full suite: 24 tests passed.
- Still open: web PKCE callback URL cleanup and recovery restoration after reload; actual PKCE/device integration testing. These are release gates, not covered by the implicit callback tests.
- Hosted privilege migration remains unapplied pending explicit approval of its reviewed scope.

## Browser PKCE recovery follow-up
- Consumed callback parameters are removed through Flutter browser history replacement. A non-secret recover=1 UI marker retains the password form when an authenticated session is restored; it grants no backend privileges.
- SDK PKCE regression verifies recovery request/verifier creation, one code exchange, verifier removal, URL cleanup and gate remount without replay. Network is mocked; no real emails were sent.
- Full Flutter suite: 26 passing tests. Live web release build succeeded. Actual browser reload with persisted storage and physical-device callbacks remain unverified.

## Live listing writes
- Implemented owner editing through existing listings endpoint; edits filter listing id, seller, university, available status and nondeleted state, and change only editable fields.
- Creation and editing trim input, validate lengths/price/category, reject missing or ambiguous campus pickup zones, and require the current confirmed account. Existing remote photos are preserved; new uploads remain unfinished.
- Cache updates use the returned server row, avoiding a second feed request after a successful write. A zero-row response fails without changing cached content.
- Full suite: 31 tests passed, including mocked SDK create/edit, invalid input, outsider and rejected-write cases. These prove client behavior, not hosted authorization: existing database policies still require hardening before release.
- Remaining related work: storage uploads, sell-screen remote-photo preview and live success wording, full listing management, server authorization tests, actual multiuser/device verification.

## Listing photo adapter
- Added private Supabase upload and signed URL resolution, scoped random object names, byte-size/format checks, and truthful MIME detection for picked PNG/JPEG files.
- Sell screen previews existing HTTPS images and distinguishes live saves from local demo saves.
- Upload denial prevents listing persistence. Signed URL failures use image fallback after successful writes.
- Storage is not provisioned on the hosted project. STORAGE_SETUP.md records the required policies, actual-device tests, URL refresh and orphan cleanup still needed before release.
- Full suite passed 34 tests, followed by a seventh passing listing-write test for upload denial (35 total tests now). Final analyzer/build results are recorded separately when complete.
- Final verification: all 35 tests pass; analyzer clean; live web release build succeeded.

## Native CI milestone
- Pushed deployment-readiness branch to GitHub and installed pinned Android/iOS build verification.
- Run 34325217597 succeeded at source commit 4a4613a: analyzer and 35 tests, Android debug APK, unsigned iOS release app.
- Downloaded and inspected both artifacts; SHA-256 and run link are in NATIVE_BUILDS.md.
- Native compilation is now verified. Device behavior, production signing, backend/storage hardening and remaining marketplace flows are still incomplete; deployment goal remains active.

## Live offer and listing-status adapter
- Implemented cash-offer RPC calls with positive whole-dollar validation and cached buyer/listing checks. The confirmed server offer ID is added to the conversation without a follow-up read that could misreport success and cause duplicate submission.
- Implemented mark-sold using owner/university/available/nondeleted filters and confirmed returned rows. Failed writes leave cached status unchanged.
- Live feed reads retain a seller's unavailable listings so sold items remain available in their profile; home/search already filter available status.
- Local verification: 39-test full suite and clean analyzer, plus an additional passing rejection test (40 tests total). Mocked SDK tests do not prove hosted authorization or multiuser transaction correctness.
- Hosted read-only review confirms anon cannot execute respond_to_offer, while authenticated can. Current function lacks explicit active-account, expiration and listing-availability checks before acceptance; server hardening and concurrency tests remain release gates. No hosted function was changed and no real offer was sent.
- Final full-suite verification: all 40 tests passed.
