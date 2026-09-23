import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Messages the marketplace RPCs raise on purpose (see
/// supabase/migrations/*_enforce_verified_marketplace_access.sql). Only
/// these are shown verbatim; Postgres' own errors share their SQLSTATEs.
const _serverMessages = {
  'Offer expired',
  'Offer no longer pending',
  'Offer unavailable',
  'Listing unavailable',
  'Offered listing unavailable',
  'Conversation unavailable',
  'Message must be between 1 and 2000 characters',
  'University access required',
  'University access requires review',
  'Report unavailable',
  'Invalid report',
  'Account unavailable',
  'Admin access required',
  'Admins cannot be suspended here',
};

/// User-facing text for a failed action. The repositories throw
/// StateError/ArgumentError with messages written for users; anything else
/// (network, server, auth exceptions) gets a generic message so raw
/// exception text never reaches the screen.
String friendlyError(Object error) => switch (error) {
  StateError(:final message) => message,
  ArgumentError(:final message) when message is String => message,
  PostgrestException(:final message) when _serverMessages.contains(message) =>
    message,
  StorageException() =>
    'The photo could not be uploaded. Try again, or post without a photo.',
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
