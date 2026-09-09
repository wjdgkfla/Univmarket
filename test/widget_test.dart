import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('home and search work at phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.text('UnivMarket'), findsOneWidget);
    expect(find.textContaining('LOCAL DEMO'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'headphones');
    await tester.pumpAndSettle();
    expect(find.text('Sony wireless headphones'), findsOneWidget);
    expect(find.text('Reading chair'), findsNothing);
    await tester.enterText(find.byType(TextField), 'nothing matches this');
    await tester.pumpAndSettle();
    expect(find.textContaining('No matches.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sell form posts the entered data', (tester) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sell').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'My spare monitor');
    await tester.enterText(fields.at(1), '65');
    await tester.enterText(
      fields.at(2),
      'A working monitor with an HDMI cable.',
    );
    await tester.ensureVisible(find.text('Post listing'));
    await tester.tap(find.text('Post listing'));
    await tester.pumpAndSettle();
    expect(repo.listListings().first.title, 'My spare monitor');
    expect(repo.listListings().first.price, 65);
    expect(find.text('My spare monitor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('demo chat accepts a received offer without using Supabase', (
    tester,
  ) async {
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Morgan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Item reserved in this demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
