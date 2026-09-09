import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/data/supabase_client.dart';

// Moved here from test/widget_test.dart: the repository now does real
// Supabase network I/O on bootstrap, which plain `flutter test` cannot do
// (see that file for why). These need a real device/emulator:
//   flutter test integration_test/app_test.dart -d <device>
//
// Two behavioral notes carried over from the old demo-mode tests:
//
// 1. Anonymous sign-in creates a brand-new, never-before-seen user each
//    run — never Maya Chen or Devon Ruiz, the two seeded identities. A
//    fresh anonymous buyer starting a conversation always gets an *empty*
//    thread, never the seeded pending-offer one. The accept-offer flow
//    test is skipped for that reason (would need real Maya/Devon login,
//    out of scope here).
// 2. Every test needs Anonymous Sign-Ins enabled in the project's Auth
//    settings, or bootstrap fails and nothing renders past the loading
//    screen.

Future<void> settle(WidgetTester tester) async {
  // AmbientGlow animates forever, so pumpAndSettle would time out — poll
  // instead, bounded, enough for the Supabase bootstrap round-trip to land.
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initSupabase();
  });

  testWidgets('Home screen loads with wordmark and bottom nav', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(UnivMarketApp(repository: Repository()));
    await settle(tester);

    expect(find.textContaining('Market'), findsWidgets);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsWidgets);
  });

  testWidgets(
    'Tapping a listing opens detail and offer flow mutates state',
    (WidgetTester tester) async {
      await tester.pumpWidget(UnivMarketApp(repository: Repository()));
      await settle(tester);

      await tester.tap(find.text('Sony WH-1000XM4, black').first);
      await settle(tester);
      expect(find.text('Make offer'), findsOneWidget);

      await tester.tap(find.text('Make offer'));
      await settle(tester);
      // A brand-new anonymous buyer opens an empty thread with the seller,
      // not the seeded pending-offer conversation — so there's no "Accept"
      // button to find here the way the old demo-mode test expected.
      expect(find.text('Send message'), findsOneWidget);
    },
    skip: true, // TODO: needs a real (non-anonymous) Maya/Devon login.
  );

  testWidgets(
    'Messaging a different listing opens that listing\'s own conversation, not a hardcoded one',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(UnivMarketApp(repository: Repository()));
      await settle(tester);

      await tester.tap(find.textContaining('armchair').first);
      await settle(tester);
      expect(find.text('Message'), findsOneWidget);

      await tester.tap(find.text('Message'));
      await settle(tester);
      expect(find.text('Devon Ruiz'), findsWidgets);
      expect(find.text('Maya Chen'), findsNothing);
    },
  );
}
