import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/inbox_screen.dart';

class IncomingRepository extends Repository {
  IncomingRepository() : super.offline();
  bool unavailable = false;
  int revision = 0;
  List<Conversation> threads = [];
  @override
  Future<void> refreshInbox() async {
    if (unavailable) throw StateError('offline');
    revision++;
    threads = [
      Conversation(
        id: 'thread',
        sellerId: 'seller',
        listingId: 'listing',
        unread: true,
        messages: [
          TextMessage('m$revision', MessageFrom.them, 'Incoming $revision'),
        ],
      ),
    ];
    notifyListeners();
  }

  @override
  List<Conversation> listConversations() => threads;
  @override
  Profile? getSeller(String id) => null;
}

void main() {
  testWidgets(
    'inbox refreshes on open and after resume, not on a timer while open',
    (tester) async {
      final repo = IncomingRepository();
      await tester.pumpWidget(
        ChangeNotifierProvider<Repository>.value(
          value: repo,
          child: const MaterialApp(home: InboxScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Incoming 1'), findsOneWidget);
      // Ongoing freshness while open now comes from the app-wide realtime
      // listener (InboxLiveSync), not from this screen polling on a timer.
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(repo.revision, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(repo.revision, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Incoming 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );

  testWidgets('inbox refresh failure is retryable', (tester) async {
    final repo = IncomingRepository()..unavailable = true;
    await tester.pumpWidget(
      ChangeNotifierProvider<Repository>.value(
        value: repo,
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    repo.unavailable = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Incoming 1'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
}
