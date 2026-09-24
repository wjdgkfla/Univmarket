import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'demo_repository.dart';
import 'package:univmarket_app/data/models.dart';

void main() {
  testWidgets('a typed pickup spot posts alongside the fixed zones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sell').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Desk chair');
    await tester.enterText(fields.at(1), '15');
    await tester.enterText(fields.at(2), 'A comfortable desk chair.');

    final pickupDropdown = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.ensureVisible(pickupDropdown);
    await tester.tap(pickupDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other — type a building name').last);
    await tester.pumpAndSettle();
    expect(find.text('Building or spot name'), findsOneWidget);

    await tester.ensureVisible(find.text('Post listing'));
    await tester.tap(find.text('Post listing'));
    await tester.pump();
    // Too short to be a real spot.
    expect(find.text('Use at least 3 characters.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('sell-custom-pickup')),
      'Room 204, North dorm',
    );
    await tester.ensureVisible(find.text('Post listing'));
    await tester.tap(find.text('Post listing'));
    await tester.pumpAndSettle();
    expect(repo.listListings().first.zone, 'Room 204, North dorm');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a listing can drop one of several photos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repo = await DemoRepository.open();
    await repo.createListing(
      title: 'Bike with two photos',
      price: 90,
      condition: Condition.good,
      category: 'Bikes',
      description: 'A campus bike, shown from two angles.',
      acceptsTrades: false,
      pickupZoneName: repo.pickupZones.first,
      imageSources: const ['assets/images/bike.jpg', 'assets/images/chair.jpg'],
    );
    final id = repo.listListings().first.id;
    expect(repo.getListing(id)!.images, hasLength(2));

    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    // Home's grid tile opens the listing, then "Edit listing".
    await tester.tap(find.text('Bike with two photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit listing'));
    await tester.pumpAndSettle();
    final removeButtons = find.byIcon(CupertinoIcons.xmark);
    expect(removeButtons, findsNWidgets(2));

    await tester.tap(removeButtons.first);
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repo.getListing(id)!.images, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
