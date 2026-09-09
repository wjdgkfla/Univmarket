import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const nativeAuthCallback = 'com.univmarket.app://auth-callback/';

abstract interface class RecoveryService {
  Future<void> sendResetEmail(String email);
  Future<void> updatePassword(String password);
}

class SupabaseRecoveryService implements RecoveryService {
  SupabaseRecoveryService(this.client);
  final SupabaseClient client;
  @override
  Future<void> sendResetEmail(String email) =>
      client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? '${Uri.base.origin}/' : nativeAuthCallback,
      );
  @override
  Future<void> updatePassword(String password) async {
    if (password.length < 12) {
      throw ArgumentError('Use at least 12 characters.');
    }
    if (client.auth.currentSession == null) {
      throw StateError('Open a valid recovery link first.');
    }
    await client.auth.updateUser(UserAttributes(password: password));
  }
}
