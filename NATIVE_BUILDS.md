# Native build verification

GitHub Actions runs analysis and Flutter tests, then builds a live-backend Android debug APK on Linux and an unsigned iOS release app on macOS. Flutter and action revisions are pinned. No signing credentials or service-role keys are used. The committed Supabase configuration contains a publishable client key.

Workflow: `.github/workflows/native-build.yml`. It runs on pull requests and pushes to main or codex branches. Successful runs provide artifacts retained for seven days:

- `android-live-debug-apk`: installable Android test APK, not suitable for Play Store upload.
- `ios-live-unsigned-app`: unsigned compiled iOS app for inspection, not installable through TestFlight and not a signed IPA.

Green compilation does not prove device behavior or backend authorization. Before public distribution, complete the backend release gates and two-device pilot, choose final application identifiers, configure owner-controlled Android signing and Apple certificates/provisioning, then build the signed AAB and IPA. Keep private signing material out of Git.

Reference: https://docs.flutter.dev/deployment/ios and https://docs.flutter.dev/deployment/android

## Verified native build: 2026-09-09

Run: https://github.com/wjdgkfla/Univmarket/actions/runs/34325217597
Source commit: `4a4613a9d02d62e044a166eb4705df8ed3211bad`.

All jobs succeeded: quality (analysis and 35 tests), Android debug APK, and iOS release without signing. Android finished in 5m1s; iOS finished in 3m37s. Both use the committed live-backend configuration.

Downloaded artifacts were inspected locally: the APK contains AndroidManifest.xml, classes.dex and Flutter libraries for arm64-v8a, armeabi-v7a and x86_64; the iOS archive contains Runner.app/Runner plus App.framework and Flutter.framework. Files are ignored build output under `build/native-evidence`.

SHA-256:
- Android APK: `8E8E154A4FA34C7278D824E66100B0714C5B04B4FE9F4E3968E596EBB033C3DE`
- iOS archive: `B8D3BA9773BE4D1996842DC155247FA1D12FA25F24F4176B104E1EFB444B9B55`

This verifies native compilation and packaging. No physical-device execution, Android release signing, iOS signing, TestFlight upload, or Play submission has been performed. The local Windows machine still lacks an Android SDK and connected phone.
