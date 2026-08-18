// The repository is now Supabase-backed and does real network I/O on
// bootstrap (anonymous sign-in, ensure_profile, listing/conversation
// fetches). `flutter test` runs under TestWidgetsFlutterBinding, which
// rejects all real HTTP requests (any HttpClient created in that binding
// returns status 400) and has no shared_preferences plugin implementation
// for supabase_flutter's session storage — there's no mocking layer for
// either in place, and building one was out of scope for this pass.
//
// So these are integration tests now, not widget tests: see
// integration_test/app_test.dart, which needs a real device/emulator and
// runs via `flutter test integration_test/app_test.dart -d <device>`.

void main() {}
