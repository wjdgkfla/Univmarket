import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/chat_screen.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';
import 'package:univmarket_app/screens/home_screen.dart';

class SlowChatRepository extends Repository {
  SlowChatRepository() : super.offline();
  final pending = Completer<void>();
  int sends = 0;
  @override
  bool get isDemo => true;
  @override
  Profile? getSeller(String id) => null;
  @override
  Conversation? getConversation(String id) => Conversation(
    id: id,
    sellerId: 'seller',
    listingId: 'listing',
    unread: false,
    messages: List.generate(
      30,
      (i) => TextMessage('$i', MessageFrom.them, 'Message $i'),
    ),
  );
  @override
  Future<void> sendMessage(String id, String body) async {
    sends++;
    await pending.future;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'chat opens at latest message and prevents duplicate sends without erasing a new draft',
    (tester) async {
      final repo = SlowChatRepository();
      await tester.pumpWidget(
        ChangeNotifierProvider<Repository>.value(
          value: repo,
          child: const MaterialApp(home: ChatScreen(id: 'thread')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Message 29').hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'First message');
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send message'));
      expect(repo.sends, 1);
      await tester.enterText(find.byType(TextField), 'Next draft');
      repo.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Next draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty search can reset both query and filters', (tester) async {
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(HomeScreen))).go('/search');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'no matching item');
    await tester.tap(find.text('Free'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear search and filters'));
    await tester.pumpAndSettle();
    expect(find.text('6 results'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  for (final scale in [1.0, 1.8]) {
    testWidgets('main screens fit a 320px phone at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = await DemoRepository.open();
      await tester.pumpWidget(UnivMarketApp(repository: repo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      for (final path in [
        '/search',
        '/sell',
        '/saved',
        '/inbox',
        '/chat/gmu-welcome',
        '/profile',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
    });
  }

  testWidgets('missing chat and edit links have a recovery action', (
    tester,
  ) async {
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go('/chat/missing');
    await tester.pumpAndSettle();
    expect(find.text('Back to inbox'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    router.go('/edit/missing');
    await tester.pumpAndSettle();
    expect(find.text('Back to marketplace'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
  });

  testWidgets('cancelling an offer does not create a conversation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    ).go('/listing/gmu-item-0');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Make offer'));
    await tester.tap(find.text('Make offer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.listConversations(), hasLength(1));
  });
}
