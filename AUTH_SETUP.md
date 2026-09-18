# Authentication release configuration

The app implements email/password sign-in and registration, reset-email requests, password updates, local sign-out, and callback handling for cold starts and resumed apps. This is not yet a verified production email setup.

## Supabase settings required before testing with real accounts

- Enable email confirmation; do not use anonymous sign-in for this app.
- Add `com.univmarket.app://auth-callback/` to Authentication URL Configuration's redirect allowlist.
- For a web staging build, allow its exact HTTPS origin followed by `/`. The recovery service uses the current web origin; the local demo address is not a production URL.
- Configure the owner-controlled SMTP provider, sender identity, rate limits and password policy. The app requires 12 characters for registration and new passwords; the server policy must enforce the intended minimum too.
- Verify the email template uses Supabase's confirmation URL. PKCE reset links must be opened on the device that requested the reset.

No hosted authentication settings or email templates were modified by this implementation. No test emails were sent.

## Native configuration

AndroidManifest.xml and Info.plist register the callback scheme. Flutter's default deep-link routing is disabled for these callbacks. LiveAuthGate subscribes to auth events before processing the initial link; Supabase automatic URI handling is disabled so the same link is not consumed twice. Incoming links are serialized, and the SDK validates the recovery session before the password-update screen is shown. Recovery state prevents marketplace bootstrap until the flow ends.

## Verification completed

- Reset request validates email and gives a neutral response that does not reveal account existence.
- Password confirmation, minimum length, retry after error and success messaging are covered by widget tests.
- Cold-start recovery is covered using the real Supabase SDK with isolated mock HTTP responses; the test asserts no marketplace data request occurs.
- Expired links display a generic error without exposing server details.
- Android/iOS XML files parse. This is not proof of native deep-link delivery.

## Remaining verification

Test confirmation and recovery emails on physical Android/iPhone devices, including cold launch, warm resume, expiration, replay, cancellation, and a reset link opened on another device. Verify production web callback handling on the deployed origin. Secure native refresh-token persistence, account deletion, and verified university membership remain release blockers alongside the pending database privilege migration.

The browser callback handler replaces consumed code/token URLs with /?recover=1 during password recovery. This marker selects the password form only when a session exists. Finishing recovery signs out and removes the marker. SDK tests cover PKCE exchange and widget remount; verify actual browser refresh and persisted sessions before release.

## Native secure persistence

On iOS and Android, Supabase now uses flutter_secure_storage 11.0.0 for session and PKCE verifier persistence. iOS uses first-unlock, device-only Keychain accessibility; Android uses the plugin's default encrypted storage. Android app backup is disabled and the iOS target declares Keychain entitlements. Web keeps Supabase's browser storage.

At startup, legacy preference values are migrated only after a secure copy is written and read back successfully. Existing secure values take precedence. A failed write preserves the legacy value and fails startup rather than silently discarding credentials. Sign-out removes the protected session and outstanding recovery verifier. Storage keys are scoped to the Supabase project.

Mocked storage tests cover migration, failed-write preservation, deletion and project isolation. These do not prove Keychain/Keystore behavior on a physical device. Before release, test cold restart, locked-device resume, sign-out followed by restart, backup/restore and recovery links on both native platforms.
