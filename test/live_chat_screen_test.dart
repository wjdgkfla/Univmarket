import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/chat_screen.dart';

class RecoveringChatRepository extends Repository {
  RecoveringChatRepository() : super.offline();
  int calls = 0;
  Conversation? thread;
  @override
  List<Stream<Object?>> conversationChanges(String id) => [];
  @override
  Profile? getSeller(String id) => null;
  @override
  Conversation? getConversation(String id) => thread;
  @override
  Future<void> refreshConversation(String id) async {
    calls++;
    if (calls == 1) throw StateError('offline');
    thread = Conversation(
      id: id,
      sellerId: 'seller',
      listingId: 'listing',
      unread: false,
      messages: [],
    );
    notifyListeners();
  }
}

class DelayedSendRepository extends RecoveringChatRepository {
  DelayedSendRepository() {
    thread = const Conversation(
      id: 'thread',
      sellerId: 'seller',
      listingId: 'listing',
      unread: false,
      messages: [],
    );
  }
  final sent = Completer<void>();
  @override
  bool get isDemo => true;
  @override
  Future<void> markConversationRead(String id) async {}
  @override
  Future<void> sendMessage(String id, String body) => sent.future;
}

void main() {
  testWidgets('returning to chat after backgrounding recovers missed updates', (
    tester,
  ) async {
    final repo = RecoveringChatRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<Repository>.value(
        value: repo,
        child: const MaterialApp(home: ChatScreen(id: 'thread')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Chat updates are unavailable'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Chat updates are unavailable'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
  testWidgets('opening a long conversation shows its newest message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = DelayedSendRepository();
    repo.thread = repo.thread!.copyWith(
      messages: [
        for (var i = 0; i < 40; i++)
          TextMessage('m$i', MessageFrom.them, 'Message number $i'),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<Repository>.value(
        value: repo,
        child: const MaterialApp(home: ChatScreen(id: 'thread')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Message number 39').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
  testWidgets(
    'sending a message preserves text typed while the request is pending',
    (tester) async {
      final repo = DelayedSendRepository();
      await tester.pumpWidget(
        ChangeNotifierProvider<Repository>.value(
          value: repo,
          child: const MaterialApp(home: ChatScreen(id: 'thread')),
        ),
      );
      await tester.enterText(find.byType(TextField), 'First message');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Next message');
      repo.sent.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Next message',
      );
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
  testWidgets(
    'live chat shows retry on failed initial load and then opens conversation',
    (tester) async {
      final repo = RecoveringChatRepository();
      await tester.pumpWidget(
        ChangeNotifierProvider<Repository>.value(
          value: repo,
          child: const MaterialApp(home: ChatScreen(id: 'thread')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Chat updates are unavailable'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.textContaining('Chat updates are unavailable'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
}
