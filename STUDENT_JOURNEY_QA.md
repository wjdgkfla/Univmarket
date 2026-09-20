# Student journey audit — September 20, 2026

## Scope and limits

Functional audit, not a claim that the app is bug-free. No production accounts,
messages, listings, auth settings or database records were changed in this pass.
Email-provider setup, branding and optional services are deferred in NEXT_TIME.md.

The production web entrypoint was opened signed out. Authenticated UI was exercised
separately with the existing offline repository, at a 440 × 956 browser viewport.
Those fixtures do not verify Supabase delivery or authorization. Docker's local
Linux engine was unavailable, so an isolated real-backend journey could not run.
No physical iPhone or signed iOS installation was available for this pass.

## Reproduced and corrected

- Canceling an offer created an unwanted inbox conversation. Create it only after
  the buyer confirms an amount; cancellation and successful submission are tested.
- Chat did not refresh after backgrounding. Resume now triggers a retryable reload.
- Switching tabs destroyed an unfinished listing. Tabs now retain their state for
  the current app session; successful posting clears the completed form.
- Review caught two consequences of persistent tabs: edits during an in-flight
  save could be lost, and completion could eject the user from Search or Chat.
  Inputs are disabled during saving and navigation occurs only while the form is
  the visible route. Delayed-request regression tests cover both cases.

## Verification coverage

Final local checks: 86 unit/widget tests passed; Flutter analysis reported no
issues; the normal Supabase-backed web release build and the isolated QA web
build succeeded. Independent focused review found no remaining critical or
important issues after the delayed-save corrections.

| Journey | Evidence | Limit |
| --- | --- | --- |
| First launch → welcome → signup | Production web browser; blank form shows field errors | No account created |
| Auth, email callbacks, password recovery | Automated HTTP-fixture and widget tests | Real email delivery and native link handoff pending |
| Browse → save → Saved → listing detail | Manual browser with offline fixtures | Not live database persistence |
| Contact seller → send message | Manual browser; message appears and composer clears | Not cross-device delivery |
| Return later → Saved | Browser reload retains local fixture favorite | Not live session renewal |
| Search, filters, posting, offers, profile, unavailable records | Existing and new widget/repository tests | Device/network integration pending |
| Tab-switch draft, successful post clearing, delayed post | New widget tests | Drafts are session-only, not crash recovery |
| Small screens and enlarged text | 320px / 1.3× and 390px / 2× iOS-target widget layout tests | Not VoiceOver or physical keyboard testing |

## Repeat the isolated browser walkthrough

```powershell
flutter build web --release --target test/support/student_preview.dart --output build/student-qa
node scripts/preview.mjs --student-qa
```

Open http://127.0.0.1:4174. This explicitly labeled fixture build stores actions
locally and never initializes Supabase. Never ship this target. The normal release
entrypoint remains lib/main.dart and requires real authentication.

The updated integration_test/app_test.dart is a clean-install, signed-out device
smoke test. It replaces obsolete anonymous/Fenwick assumptions. It is not included
in the ordinary flutter test run and has not been executed on an iPhone.

## Release gates still outstanding

1. Verified GMU and GWU accounts with working confirmation and reset email.
2. Two-device real seller/buyer test: upload a photo, post, save, message, offer,
   accept/decline, reserve/mark sold, reconnect, sign out and back in.
3. Signed iPhone test: photo permissions, keyboard, safe areas, native back gestures,
   accessibility, warm/cold email links, offline recovery and installation/update.

Do not interpret passing fixture tests or a web build as completion of these gates.
