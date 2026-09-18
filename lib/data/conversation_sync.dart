import 'dart:async';
import 'package:flutter/foundation.dart';

/// Coalesces realtime events and keeps refresh failures visible and retryable.
class ConversationSync extends ChangeNotifier {
  ConversationSync({
    required List<Stream<Object?>> changes,
    required this.load,
  }) {
    for (final stream in changes) {
      _subscriptions.add(
        stream.listen(
          (_) => unawaited(refresh()),
          onError: (Object _) => _setFailed(true),
        ),
      );
    }
  }
  final Future<void> Function() load;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool failed = false;
  bool _disposed = false;
  bool _again = false;
  Future<void>? _active;

  void _setFailed(bool value) {
    if (_disposed || failed == value) return;
    failed = value;
    notifyListeners();
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_active != null) {
      _again = true;
      return _active!;
    }
    // Schedule after storing _active, even if load throws synchronously.
    return _active = Future<void>.microtask(() async {
      do {
        _again = false;
        try {
          await load();
          _setFailed(false);
        } catch (_) {
          _setFailed(true);
        }
      } while (_again && !_disposed);
    }).whenComplete(() => _active = null);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
