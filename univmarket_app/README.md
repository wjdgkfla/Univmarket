# UnivMarket

A Flutter iOS/Android campus marketplace. This checkout includes a working **local demo**, a browser preview of the shared Flutter UI, and an opt-in legacy Supabase adapter. It is not yet a live multi-user release.

## Run the preview

From this directory, with Flutter on PATH:

```sh
flutter pub get
flutter build web --release
node scripts/preview.mjs
```

Open [the local preview](http://127.0.0.1:4173/). Keep the terminal running. Always use the same address and port to keep browser demo storage consistent.

For hot reload, run `flutter run -d chrome` with Flutter on PATH. For a native device, install/configure the Android SDK (or Xcode on macOS), connect a device, then use `flutter devices` and `flutter run -d DEVICE_ID`.

## Try these flows

- Select George Mason, Virginia Tech, or University of Maryland. Each has a separate **sample** feed; these are not launched campus communities.
- Search, filter by condition/price/free, and sort results.
- Save a listing, navigate to Saved, and reload: saved items persist.
- Sell: choose a photo, enter your own details, select pickup, and post. Find your listing on Home or Profile; edit it or mark it sold.
- Open a sample listing and message its seller or send a cash offer.
- Open the pre-seeded Inbox conversation and accept its sample incoming offer: its listing becomes reserved. Repeat acceptance is rejected.

All demo messages, photos, favorites, offers, and listing changes stay in this device/browser's local storage. No real seller receives a message, no email is verified, and no transaction or payment occurs. Demo photos are illustrative; see [image sources](assets/IMAGE_SOURCES.md). Clearing app/browser data resets the demo. The local photo limit is 1.5 MB per image; large collections can exceed browser storage capacity.

## Verification

```sh
flutter analyze
flutter test --no-pub
flutter build web --release
```

The default tests are offline and do not create Supabase accounts. The older integration_test suite targets the legacy live backend and is not part of the verified offline suite.

## Live backend status

Live mode is explicitly selected with `--dart-define=LIVE_BACKEND=true`, `--dart-define=SUPABASE_URL=...`, and `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`. Only a publishable key belongs in the app.

The retained adapter is a development reference: it still has anonymous bootstrap and single-university assumptions and requires existing server RPCs. It is **not suitable for public launch**, and adding credentials does not make it multi-university ready. Editing/photo upload/new offer creation deliberately report unsupported in that adapter rather than pretending to work. Demo mode never initializes Supabase, and a failed live connection never silently opens demo mode.

Read [the deployment plan](../docs/DEPLOYMENT_PLAN.md) before enabling shared accounts or distributing builds publicly.
