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
