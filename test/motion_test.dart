import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';
import 'package:univmarket_app/widgets/fade_slide_in.dart';

double _opacityOf(WidgetTester tester, Finder text) => tester
    .widget<Opacity>(
      find.ancestor(of: text, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('entrance fades in, and is instant with reduced motion', (
    tester,
  ) async {
    Widget item(bool reduce) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FadeSlideIn(key: UniqueKey(), child: const Text('item')),
      ),
    );
    await tester.pumpWidget(item(false));
    expect(_opacityOf(tester, find.text('item')), 0);
    await tester.pumpAndSettle();
    expect(_opacityOf(tester, find.text('item')), 1);

    await tester.pumpWidget(item(true));
    await tester.pump();
    expect(_opacityOf(tester, find.text('item')), 1);
  });

  testWidgets('chat history is at rest and a new message slides in', (
    tester,
  ) async {
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Morgan').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final history = find.textContaining('Try accepting this sample offer');
    expect(_opacityOf(tester, history), 1);

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Is it still available?');
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    final sent = find.text('Is it still available?');
    expect(_opacityOf(tester, sent), lessThan(1));
    await tester.pumpAndSettle();
    expect(_opacityOf(tester, sent), 1);
    expect(_opacityOf(tester, history), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab switch fades the new tab in and keeps the old one', (
    tester,
  ) async {
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lamp');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // The tab fade is the only CurvedAnimation-driven fade above the screen.
    final tabFade = tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: find.text('Saved for later'),
            matching: find.byType(FadeTransition),
          ),
        )
        .singleWhere((f) => f.opacity is CurvedAnimation);
    expect(tabFade.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'lamp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
