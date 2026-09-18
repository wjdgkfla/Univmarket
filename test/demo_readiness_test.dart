import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/screens/home_screen.dart';
import 'package:univmarket_app/widgets/async_action.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(DemoRepository, GoRouter)> pumpApp(WidgetTester tester) async {
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    return (repo, GoRouter.of(tester.element(find.byType(HomeScreen))));
  }

  testWidgets('opening a chat clears its unread dot', (tester) async {
    final (repo, router) = await pumpApp(tester);
    expect(repo.listConversations().single.unread, isTrue);
    router.go('/inbox');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex Morgan'));
    await tester.pumpAndSettle();
    expect(repo.listConversations().single.unread, isFalse);
  });

  testWidgets('empty Saved and category show guidance with an action', (
    tester,
  ) async {
    final (_, router) = await pumpApp(tester);
    router.go('/saved');
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsOneWidget);
    await tester.tap(find.text('Browse listings'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.ensureVisible(find.text('Apparel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apparel'));
    await tester.pumpAndSettle();
    expect(find.text('No Apparel yet'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('No Apparel yet'), findsNothing);
  });

  testWidgets('mark as sold asks for confirmation first', (tester) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (repo, router) = await pumpApp(tester);
    await repo.createListing(
      title: 'My spare monitor',
      price: 40,
      condition: Condition.good,
      category: 'Electronics',
      description: 'A working monitor with a cable.',
      acceptsTrades: false,
      pickupZoneName: repo.pickupZones.first,
    );
    final id = repo.listListings().first.id;
    router.go('/listing/$id');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mark as sold'));
    await tester.tap(find.text('Mark as sold'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as sold?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.getListing(id)!.status, 'available');

    await tester.tap(find.text('Mark as sold'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Mark as sold'));
    await tester.pumpAndSettle();
    expect(repo.getListing(id)!.status, 'sold');
  });

  test('errors shown to users never include raw exception text', () {
    expect(
      friendlyError(StateError('Listing unavailable')),
      'Listing unavailable',
    );
    expect(friendlyError(ArgumentError('Enter a price')), 'Enter a price');
    expect(
      friendlyError(Exception('PostgrestException(code: 42501)')),
      isNot(contains('42501')),
    );
  });
}
