import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'demo_repository.dart';
import 'package:univmarket_app/screens/home_screen.dart';
import 'package:univmarket_app/screens/search_screen.dart';
import 'package:univmarket_app/screens/sell_screen.dart';
import 'package:univmarket_app/screens/saved_screen.dart';
import 'package:univmarket_app/screens/inbox_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('switching tabs never shows the previous tab underneath', (
    tester,
  ) async {
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.text('Fresh on campus'), findsOneWidget);

    await tester.tap(find.text('Saved').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Saved for later'), findsOneWidget);
    expect(find.text('Fresh on campus'), findsNothing);
  });

  testWidgets(
    'rapid tab switches paint only the selected screen on every frame',
    (tester) async {
      final repo = await DemoRepository.open();
      await tester.pumpWidget(UnivMarketApp(repository: repo));
      await tester.pumpAndSettle();
      const screens = {
        'Home': HomeScreen,
        'Search': SearchScreen,
        'Sell': SellScreen,
        'Saved': SavedScreen,
        'Inbox': InboxScreen,
      };
      for (final target in [
        'Search',
        'Sell',
        'Saved',
        'Inbox',
        'Home',
        'Inbox',
        'Saved',
        'Sell',
        'Search',
        'Home',
      ]) {
        await tester.tap(find.text(target).last);
        for (final elapsed in [0, 16, 80]) {
          await tester.pump(Duration(milliseconds: elapsed));
          for (final entry in screens.entries) {
            expect(
              find.byType(entry.value),
              entry.key == target ? findsOneWidget : findsNothing,
            );
          }
          for (final scaffold in tester.widgetList<Scaffold>(
            find.byType(Scaffold),
          )) {
            expect(scaffold.backgroundColor, isNot(Colors.transparent));
          }
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );

  testWidgets('chat pushed over inbox paints an opaque background', (
    tester,
  ) async {
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Morgan').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final scaffolds = tester.widgetList<Scaffold>(find.byType(Scaffold));
    expect(
      scaffolds.where((s) => s.backgroundColor == Colors.transparent),
      isEmpty,
    );
  });
}
