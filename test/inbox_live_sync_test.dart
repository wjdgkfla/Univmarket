// Regression coverage for bug B1: the tab-bar unread dot only updated once
// the Inbox tab had been opened and its own poll ticked, so a new message
// while on Home/Search/Saved/Sell left it stale indefinitely. The fix adds
// an app-wide realtime subscription (InboxLiveSync) instead.
//
// ConversationSync's own coalescing/retry mechanics are covered by
// test/conversation_sync_test.dart, and every other widget test in this
// suite pumps an offline/demo Repository through the full app shell
// (including this widget) without a mocked realtime server — so the one
// thing that actually matters to test here, safety-critical for the rest
// of the suite, is that an offline/demo repository (client == null) never
// touches the stream at all.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/widgets/inbox_live_sync.dart';

class _FakeIncomingRepository extends Repository {
  _FakeIncomingRepository() : super.offline();
  final controller = StreamController<Object?>.broadcast();
  int refreshCalls = 0;
  @override
  Stream<Object?> incomingMessages() => controller.stream;
  @override
  Future<void> refreshInbox() async {
    refreshCalls++;
  }
}

void main() {
  testWidgets(
    'an offline/demo repository (no client) never subscribes to the stream',
    (tester) async {
      final repo = _FakeIncomingRepository();
      addTearDown(repo.controller.close);
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        InboxLiveSync(repository: repo, child: const SizedBox()),
      );
      expect(repo.controller.hasListener, isFalse);
      // Confirms this is actually exercising the guard, not a fluke of an
      // unrelated stream shape: a listener would react to this.
      repo.controller.add(null);
      await tester.pump();
      expect(repo.refreshCalls, 0);
    },
  );
}
