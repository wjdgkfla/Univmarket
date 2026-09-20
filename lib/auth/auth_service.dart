import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'recovery_service.dart';

abstract interface class AuthService {
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this.client);
  final SupabaseClient client;

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(String email, String password) async {
    await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: kIsWeb ? '${Uri.base.origin}/' : nativeAuthCallback,
    );
  }
}
