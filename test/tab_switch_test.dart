import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';

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
