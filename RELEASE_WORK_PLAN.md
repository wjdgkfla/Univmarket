# Deployment readiness implementation plan

Goal: deliver the shared iOS/Android UnivMarket app with a tested live backend and reproducible native release builds. This plan implements DEPLOYMENT_PLAN.md; a local demo or a web build alone does not satisfy completion.

Architecture: retain Flutter and the existing Supabase project. Replace anonymous bootstrap with explicit authentication; derive membership from confirmed email and approved university domains. Keep server-owned identity and transaction fields inaccessible to direct client writes. Keep the demo available as an explicit development option.

## Work sequence and evidence

- [ ] Release configuration: remove Android debug-signing fallback, validate client configuration before initializing Supabase, preserve retry behavior, test malformed/secret credentials. Files: android/app/build.gradle.kts, lib/data/backend_config.dart, lib/data/supabase_client.dart, test/backend_config_test.dart.
- [ ] Capture existing database definitions and construct versioned migrations before altering the hosted schema. Inspect functions, triggers, grants, views, policies and storage together. Preserve existing records. Prove server-side email verification and prevent clients assigning university, role, state, or reputation. Files: supabase/migrations, supabase/tests.
- [ ] Authentication/session lifecycle: email sign-up, confirmation, sign-in, recovery, sign-out, deletion, session expiry, secure native session persistence. Replace anonymous startup in lib/main.dart and lib/data/repository.dart; add testable authentication controller and screens.
- [ ] Live repository: membership-bound catalog and pickup zones, paginated listings, uploads and cleanup, favorites, edits/status, conversations and messages, cash offers, atomic acceptance and transaction completion. Tests must include buyer, seller, outsider and another university.
- [ ] Trust flows: report/block, moderation access, support/privacy disclosures, account deletion and safe meetup scheduling. Remove unsupported or fabricated metrics and claims from live UI.
- [ ] Native build pipeline: Android SDK/JDK build, iOS macOS build, final identifiers, signing from private configuration, application icons, permission and lifecycle tests. Record actual build artifacts and device results, not only configuration inspection.
- [ ] Pilot: verified two-device flow, concurrency/access-denial tests, production email/redirect configuration, operational monitoring, privacy/store materials, TestFlight and Play testing. Signing accounts and actual distribution remain owner-dependent.

## Completion evidence

Each checkbox remains open until its full behavior has authoritative evidence. Offline unit tests, REST health checks and a successful web build cannot establish native release readiness or live authorization. Do not mark this goal complete until the deployment plan's release gates and both native platforms are verified.
