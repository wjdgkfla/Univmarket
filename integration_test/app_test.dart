import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:univmarket_app/main.dart' as app;

// Run on a clean app install (no saved session):
// flutter test integration_test/app_test.dart -d <device>
//   --dart-define-from-file=config/supabase.dev.json
// Does not sign out a user's session, create accounts, or submit email.
// Authenticated multi-device testing still requires verified GMU/GWU accounts.
Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(
    finder,
    findsWidgets,
    reason:
        'Expected a clean signed-out install with working backend configuration.',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'fresh install starts at welcome and exposes real authentication',
    (tester) async {
      await app.main();
      await waitFor(tester, find.text('Welcome to UnivMarket'));
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Create account'));
      await waitFor(tester, find.text('University email'));
      expect(find.text('Password'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to welcome'));
      await waitFor(tester, find.text('Welcome to UnivMarket'));
      await tester.tap(find.text('Sign in'));
      await waitFor(tester, find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await waitFor(tester, find.text('Send reset link'));
      expect(tester.takeException(), isNull);
    },
  );
}
