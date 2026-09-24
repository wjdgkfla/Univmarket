import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'demo_repository.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/profile_screen.dart';
import 'package:univmarket_app/theme/tokens.dart';

/// Offline repository whose student still has the placeholder name.
class _NameRepo extends Repository {
  _NameRepo() : super.offline();
  final renamed = <String>[];
  @override
  Profile get me => const Profile(
    id: 'me',
    name: 'Student 3f2a1b',
    initials: 'S',
    school: 'George Mason University',
    rating: 0,
    dealsDone: 0,
    meetupsKeptPct: 0,
    avgReplyTime: '',
  );
  @override
  Future<void> updateDisplayName(String name) async => renamed.add(name);
}

Future<DemoRepository> _withOwnListing(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final repo = await DemoRepository.open();
  await repo.createListing(
    title: 'Mini fridge',
    price: 40,
    condition: Condition.good,
    category: 'Dorm',
    description: 'A small fridge that fits under a desk.',
    acceptsTrades: false,
    pickupZoneName: repo.pickupZones.first,
  );
  await tester.pumpWidget(UnivMarketApp(repository: repo));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('a new listing shows how long ago it was posted', (tester) async {
    await _withOwnListing(tester);
    expect(find.textContaining('just now'), findsWidgets);
  });

  testWidgets('sellers delete their own listing, without a save heart', (
    tester,
  ) async {
    final repo = await _withOwnListing(tester);
    await tester.tap(find.text('Mini fridge'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Posted just now'), findsOneWidget);
    expect(find.byTooltip('Save listing'), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete listing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.listListings().any((l) => l.title == 'Mini fridge'), isFalse);
    expect(find.text('Listing deleted.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('students can replace a placeholder name', (tester) async {
    final repo = _NameRepo();
    await tester.pumpWidget(
      ChangeNotifierProvider<Repository>.value(
        value: repo,
        child: MaterialApp(
          theme: buildTheme(AppColors.light),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'J');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(repo.renamed, isEmpty);

    await tester.enterText(find.byType(TextField), '  Jordan Lee ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.renamed, ['Jordan Lee']);
  });
}
