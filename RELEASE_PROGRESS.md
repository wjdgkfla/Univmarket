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
