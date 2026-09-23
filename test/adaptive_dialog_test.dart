import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('iPhone gets native confirmation and offer dialogs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));

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
    await tester.tap(find.text('Mark as sold'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final confirm = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Mark as sold'),
    );
    expect(confirm.isDestructiveAction, isTrue);
    await tester.tap(
      find.widgetWithText(CupertinoDialogAction, 'Mark as sold'),
    );
    await tester.pumpAndSettle();
    expect(repo.getListing(id)!.status, 'sold');

    router.go('/listing/gmu-item-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make offer'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    repo.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
