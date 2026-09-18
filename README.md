# UnivMarket

A university marketplace for buying and selling within campus communities. Inspired by Mason Market, UnivMarket is being built for multiple universities with a shared Flutter app for iOS and Android.

**Status: live backend · staged launch at GMU and GWU**

The browser preview runs the shared Flutter interface. Listings, favorites, photos, messages, and offers currently persist on the local device; they are not shared between users.

## What you can try

- **Campus markets** — sign in with an @gmu.edu or @gwu.edu email to enter GMUMarket or GWUMarket, each in its school colors. Your market is fixed by your email domain.
- **Discover** — search listings, filter by price and condition, and sort results.
- **Save** — keep favorites across app restarts.
- **Sell** — add a photo, publish a listing, edit it, and mark it sold.
- **Message and offer** — try local conversations, send cash offers, and accept a sample incoming offer to reserve a listing.

The sample campuses are demonstration data, not launched communities. Demo messages do not reach real sellers, and no payments are processed.

## Platform status

| Platform | Current status |
| --- | --- |
| iOS | Flutter project included; native build and device verification pending |
| Android | Flutter project included; native build and device verification pending |
| Web | Working browser preview of the shared interface |
| Supabase | Project configured and connectivity checked; production authentication and multi-university integration pending |

## Quick start

Use Flutter with Dart 3.12.2 or a compatible version satisfying the app's SDK constraint. The app was verified with Flutter 3.44.9. Node.js is needed only for the static preview server.

```sh
git clone https://github.com/wjdgkfla/Univmarket.git
cd Univmarketunivmarket_app
flutter pub get
flutter run -d chrome --dart-define-from-file=config/supabase.dev.json
```

### Static browser preview

From the repository root:

```sh
flutter build web --release
node scripts/preview.mjs
```

Open [the local preview](http://127.0.0.1:4173/) and keep the server running. Use the same browser address to retain demo data. Clearing browser or app storage resets the demo.

### Native development

With the Android SDK configured, or Xcode on macOS for iOS, connect a device and run:

```sh
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the device identifier. See the [deployment plan](DEPLOYMENT_PLAN.md) for signing, physical-device testing, and store-release requirements.

## Development checks

Run from the repository root:

```sh
flutter analyze
flutter test --no-pub
flutter build web --release
```

The offline suite covers local persistence, campus isolation, listing validation, ownership, offers, and core screens. The legacy `integration_test` suite targets the live backend and is separate from these offline checks.

## Backend

UnivMarket uses a dedicated Supabase project. Its publishable client configuration is in [`supabase.dev.json`](config/supabase.dev.json).

The app always runs against this backend and opens on the sign-in screen. It requires a university email account and supports password recovery. Pending database migrations enforce confirmed university-email membership and harden listing, chat, and offer authorization. The staged launch schools are George Mason (gmu.edu, Fairfax) and George Washington (gwu.edu, Foggy Bottom). Pickup choices are Fenwick Library and Johnson Center at GMU, and Gelman Library at GWU. These migrations are deployed to the hosted project: accounts are assigned by exact email domain, and the legacy Fenwick seed school is deactivated. See [database rollout notes](supabase/README.md); live photo uploads, remaining write flows, and end-to-end release checks still need review before public launch.

Read the [backend connection notes](BACKEND_CONNECTION.md) before enabling live mode. Never place service-role credentials or private signing keys in client configuration.

## Repository layout

```text
*.md                    Project documents shown at the repository root
android/                Android platform project
ios/                    iOS platform project
lib/                    Flutter screens, widgets, and repositories
assets/                 Bundled sample listing photos
config/                 Development backend configuration
scripts/                Preview server and backend readiness check
test/                   Offline repository and widget tests
```

## Documentation

| Guide | Purpose |
| --- | --- |
| [App guide](APP_GUIDE.md) | Run the app and explore demo flows |
| [Implementation status](IMPLEMENTATION_STATUS.md) | Current delivery and limitations |
| [Authentication setup](AUTH_SETUP.md) | Email delivery, callback configuration, and recovery test requirements |
| [Backend connection](BACKEND_CONNECTION.md) | Supabase configuration and integration findings |
| [Verification record](VERIFICATION.md) | Checks performed and their scope |
| [Deployment plan](DEPLOYMENT_PLAN.md) | Steps from local preview to native pilot release |
| [Original product plan](MOBILE_APP_MASTER_PLAN.md) | Earlier product direction; its Expo assumption is superseded by Flutter |
| [Image sources](assets/IMAGE_SOURCES.md) | Attribution for bundled sample photos |
