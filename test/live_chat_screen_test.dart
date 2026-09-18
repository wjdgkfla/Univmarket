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

void main() {
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
