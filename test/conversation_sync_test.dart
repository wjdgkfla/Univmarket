import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/data/conversation_sync.dart';

void main() {
  test('overlapping refreshes are serialized and coalesced', () async {
    final first = Completer<void>();
    var calls = 0;
    var active = 0;
    var peak = 0;
    final sync = ConversationSync(
      changes: [],
      load: () async {
        calls++;
        active++;
        if (active > peak) peak = active;
        if (calls == 1) await first.future;
        active--;
      },
    );
    addTearDown(sync.dispose);
    final pending = sync.refresh();
    await Future<void>.delayed(Duration.zero);
    sync.refresh();
    sync.refresh();
    first.complete();
    await pending;
    expect(calls, 2);
    expect(peak, 1);
  });
  test('read and stream failures are visible and a retry recovers', () async {
    final changes = StreamController<Object?>();
    var reject = true;
    final sync = ConversationSync(
      changes: [changes.stream],
      load: () async {
        if (reject) throw StateError('offline');
      },
    );
    await sync.refresh();
    expect(sync.failed, isTrue);
    reject = false;
    await sync.refresh();
    expect(sync.failed, isFalse);
    changes.addError(StateError('disconnected'));
    await Future<void>.delayed(Duration.zero);
    expect(sync.failed, isTrue);
    sync.dispose();
    await changes.close();
  });
  test(
    'disposing during a read prevents a queued reload and notifications',
    () async {
      final done = Completer<void>();
      var calls = 0;
      final sync = ConversationSync(
        changes: [],
        load: () async {
          calls++;
          await done.future;
        },
      );
      final pending = sync.refresh();
      await Future<void>.delayed(Duration.zero);
      sync.refresh();
      sync.dispose();
      done.complete();
      await pending;
      expect(calls, 1);
    },
  );
}
