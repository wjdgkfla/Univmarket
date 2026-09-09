# Native build verification

GitHub Actions runs analysis and Flutter tests, then builds a live-backend Android debug APK on Linux and an unsigned iOS release app on macOS. Flutter and action revisions are pinned. No signing credentials or service-role keys are used. The committed Supabase configuration contains a publishable client key.

Workflow: `.github/workflows/native-build.yml`. It runs on pull requests and pushes to main or codex branches. Successful runs provide artifacts retained for seven days:

- `android-live-debug-apk`: installable Android test APK, not suitable for Play Store upload.
- `ios-live-unsigned-app`: unsigned compiled iOS app for inspection, not installable through TestFlight and not a signed IPA.

Green compilation does not prove device behavior or backend authorization. Before public distribution, complete the backend release gates and two-device pilot, choose final application identifiers, configure owner-controlled Android signing and Apple certificates/provisioning, then build the signed AAB and IPA. Keep private signing material out of Git.

Reference: https://docs.flutter.dev/deployment/ios and https://docs.flutter.dev/deployment/android
