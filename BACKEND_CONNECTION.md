# UnivMarket backend connection

Project: Application for market for univs (`amzvnsphtaxkjzmsjsie`).
Dashboard: https://supabase.com/dashboard/project/amzvnsphtaxkjzmsjsie

`config/supabase.dev.json` contains the verified project URL and publishable client key. It contains no service-role secret and applies to the shared Flutter iOS, Android, and web codebase.

## Verified September 9, 2026

The project finished startup and reports ACTIVE_HEALTHY. Its existing application schema is present; no schema was overwritten or initialized during inspection. Earlier empty results were from startup and must not be treated as an empty database.

Read-only HTTP checks using the configured publishable key passed:
- Auth health: HTTP 200
- Listings endpoint: HTTP 200
- Universities endpoint: HTTP 200

These checks confirm connectivity, not authenticated write behavior or release readiness. The default browser preview remains a persistent local demo.

## Integration findings

The restored university catalog contains the active Fenwick University seed. The existing ensure_profile RPC assigns new users to Fenwick and its main campus. The retained Flutter adapter signs in anonymously and also hardcodes Fenwick. This is not verified university membership.

Existing RPC signatures match the retained adapter for start_conversation, create_message, and respond_to_offer. ensure_profile accepts an optional display name. Live photo uploads, listing editing, mark-sold, and offer creation still need implementation.

RLS is enabled on the inspected marketplace tables. Before public launch, audit grants, triggers, functions, and policies together: profile policies only check the row owner; listing INSERT checks seller ownership and active status but does not itself enforce university membership. Verify that privileged profile fields and university assignment cannot be changed through client writes. An RLS-enabled flag alone is not a security approval.

## Commands

Run from the repository root:

```sh
node scripts/check-backend.mjs
```

For development with the retained live adapter:

```sh
flutter run -d chrome --dart-define-from-file=config/supabase.dev.json
```

This opts into the legacy anonymous Fenwick flow. It is not the public multi-university release configuration. Keep the standard demo preview until verified school authentication, authorization, storage, and authenticated end-to-end flows are implemented and tested. See DEPLOYMENT_PLAN.md.
