import 'package:flutter/material.dart';

/// User-facing text for a failed action. The repositories throw
/// StateError/ArgumentError with messages written for users; anything else
/// (network, server, auth exceptions) gets a generic message so raw
/// exception text never reaches the screen.
String friendlyError(Object error) => switch (error) {
  StateError(:final message) => message,
  ArgumentError(:final message) when message is String => message,
  _ => 'Something went wrong. Check your connection and try again.',
};

void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
}

/// Surface failed mutations and keep their originating screen usable.
Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}
