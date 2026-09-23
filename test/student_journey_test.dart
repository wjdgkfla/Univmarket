import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/search_screen.dart';
import 'package:univmarket_app/screens/home_screen.dart';
import 'package:univmarket_app/screens/chat_screen.dart';

class PendingPostRepository extends Repository {
  PendingPostRepository() : super.offline();
  final complete = Completer<void>();
  @override
  bool get isDemo => true;
  @override
  List<String> get pickupZones => ['Fenwick Library'];
  @override
  Future<void> createListing({
    required String title,
    required int price,
    required Condition condition,
    required String category,
    required String description,
    required bool acceptsTrades,
    String? pickupZoneName,
    String? customPickup,
    List<String> imageSources = const [],
    String? editingId,
  }) => complete.future;
}

void main() {
  for (final scenario in ['inputs', 'search', 'chat']) {
    final checkInputs = scenario == 'inputs';
    testWidgets(
      checkInputs
          ? 'pending post prevents edits that would be lost'
          : 'background post completion does not eject the user from $scenario',
      (tester) async {
        final repo = PendingPostRepository();
        await tester.pumpWidget(UnivMarketApp(repository: repo));
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
        await tester.tap(find.text('Sell').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Spare monitor',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '65');
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'Working monitor with cable.',
        );
        await tester.ensureVisible(find.text('Post listing'));
        await tester.tap(find.text('Post listing'));
        await tester.pump();
        if (checkInputs) {
          for (final field in tester.widgetList<TextFormField>(
            find.byType(TextFormField),
          )) {
            expect(field.enabled, isFalse);
          }
          for (final field
              in tester.widgetList<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>),
              )) {
            expect(field.onChanged, isNull);
          }
          expect(
            tester
                .widget<DropdownButtonFormField<Condition>>(
                  find.byType(DropdownButtonFormField<Condition>),
                )
                .onChanged,
            isNull,
          );
        } else {
          await tester.tap(find.text('Search').last);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'textbook');
          if (scenario == 'chat') {
            router.push('/chat/test-thread');
            await tester.pumpAndSettle();
          }
        }
        repo.complete.complete();
        await tester.pumpAndSettle();
        if (!checkInputs) {
          if (scenario == 'chat') {
            expect(find.byType(ChatScreen), findsOneWidget);
          } else {
            expect(find.byType(SearchScreen), findsOneWidget);
            expect(find.text('textbook'), findsOneWidget);
          }
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        repo.dispose();
      },
    );
  }
  testWidgets('switching tabs does not erase an unfinished listing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    await tester.tap(find.text('Sell').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Spare monitor');
    await tester.enterText(find.byType(TextFormField).at(1), '65');
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sell').last);
    await tester.pumpAndSettle();
    expect(find.text('Spare monitor'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Working monitor with HDMI cable.',
    );
    await tester.ensureVisible(find.text('Post listing'));
    await tester.tap(find.text('Post listing'));
    await tester.pumpAndSettle();
    expect(
      repo.listListings().where((l) => l.title == 'Spare monitor').length,
      1,
    );
    await tester.tap(find.text('Sell').last);
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.controller!.text, isEmpty);
    }
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    repo.dispose();
  });
  testWidgets('canceling an offer leaves the buyer inbox unchanged', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    final before = repo.listConversations().map((c) => c.id).toList();
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'chair');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading chair'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Make offer'), 300);
    await tester.tap(find.text('Make offer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.listConversations().map((c) => c.id).toList(), before);
    expect(find.text('Make a cash offer'), findsNothing);
    await tester.tap(find.text('Make offer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '35');
    await tester.tap(find.text('Send offer'));
    await tester.pumpAndSettle();
    final created = repo
        .listConversations()
        .where((c) => !before.contains(c.id))
        .single;
    expect(created.messages.whereType<OfferMessage>().single.amount, 35);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    repo.dispose();
  });
}
