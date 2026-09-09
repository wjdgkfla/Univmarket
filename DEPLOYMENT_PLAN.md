# UnivMarket: path from local preview to native launch

## Current delivery

The existing Flutter app has a persistent, explicitly labeled local demo: three university sample feeds, search and filters, saved listings, photo listing creation, editing and sold status, messages, outgoing offers, and incoming-offer acceptance/reservation. Changes are local, not shared between users or devices.

This implementation continues Flutter, superseding the Expo assumption in the older planning documents. Mason Market remains a reference product. Its production database was not modified.

The app can be inspected through its Flutter web build. This is a preview of the native-oriented shared UI, not a claim of completed Android or iOS device testing.

## 1. Establish the development backend

Use a dedicated UnivMarket Supabase development project and keep migrations in this repository. The retained legacy adapter's anonymous sign-in and Fenwick defaults are not a production architecture.

Build universities, university_domains, campuses, pickup_zones, profiles, verified_memberships, listings, listing_photos, favorites, conversations, messages, offers, transactions, blocks, and reports with explicit foreign keys and indexes. School onboarding is data-driven, but each school/domain must be approved before enabling student registration.

Implement confirmed-email verification against approved domains; university selection alone grants no membership. Replace anonymous bootstrap with a native session/sign-in/onboarding flow. Support refresh, expired sessions, sign-out, and account deletion. Store refresh tokens using an appropriate secure native session-storage configuration.

Add row-level policies for verified university membership, listing ownership, private conversation participants, favorites, storage objects, blocked users, and suspended accounts. Authorization must not depend on editable user metadata. Publishable keys are allowed in clients; service-role credentials are never allowed.

Implement atomic offer creation/acceptance, reservation and transaction creation, competitor-offer closure, and meetup state changes as database operations. Model receipt direction correctly so buyers can accept sellers' counteroffers. Verify with two real accounts plus a third unrelated account, including cross-university and non-participant access attempts.

Map the typed app repository to this backend. Replace local-only photo strings with scoped Storage objects, implement upload failure cleanup, pagination, realtime, and ownership-checked editing/status updates.

## 2. Complete release-critical product flows

- Real sign-up/sign-in, email verification, university membership, and recovery.
- Report/block, moderation handling, support contact, privacy disclosures, and account deletion.
- Working transaction completion and safe meetup scheduling; no invented verification or reputation metrics.
- Server-enforced rate limits and structured operational monitoring.
- Native photo-picker recovery and size limits; push permissions and delivery if included in launch.
- Loading, permission-denied, offline, token-expiry, and retry behavior on physical devices.
- Currency/price policy: the current demo accepts USD whole dollars only.

Trades, ratings, saved-search alerts, and the broader master-plan features are not implemented in this delivery. Decide which are required for the pilot rather than exposing inactive controls.

## 3. Produce native test builds

### Android

This Windows PC currently has no Android SDK. Install Android Studio and its SDK, accept the SDK licenses, and rerun flutter doctor. Then:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d DEVICE_ID
```

Test the full flow on a physical phone, including photo library permissions, background/resume, keyboard layouts, local persistence, and later the two-account live backend. Configure the final application ID and release signing before creating an app bundle. The existing Android release configuration uses debug signing and must be replaced before store submission.

### iOS

Use macOS with Xcode or a macOS CI runner, a chosen bundle identifier, and the owner's Apple signing team:

```sh
flutter pub get
flutter build ios --no-codesign
```

This compile check is not a signed installable release. Configure signing and entitlements, verify on a physical iPhone, then archive/upload through the Apple toolchain. Photo-library purpose text is included; any additional permissions need equally specific explanations.

## 4. Pilot and release

1. Use a separate staging backend and distribute to a small internal test group.
2. Record device/OS test results and test multi-account data isolation.
3. Configure production email delivery, redirect links, storage policies, monitoring, backup/recovery, and support.
4. Prepare store descriptions, screenshots, privacy/data-safety disclosures, age/content declarations, and reviewer access.
5. Distribute via TestFlight and Google Play internal testing before store review.
6. Launch one campus with moderation coverage. Add schools through validated configuration after proving operations.

Owner inputs needed: final brand/app IDs, pilot campus, Supabase project access, support/privacy contact, Apple/Google developer accounts, and signing configuration. Do not paste private signing keys or service-role keys into source files.

## Release gates

No public release until live authentication, tenant isolation, uploads, messaging, ownership, offer concurrency, report/block, account deletion, and device testing pass. The existing browser preview is intentionally labeled as a local demo throughout the core flows.
