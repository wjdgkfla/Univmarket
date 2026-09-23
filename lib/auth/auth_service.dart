import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'recovery_service.dart';

abstract interface class AuthService {
  Future<void> signIn(String email, String password);

  /// [name] becomes the profile's display name on first sign-in.
  Future<void> signUp(String email, String password, String name);
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this.client);
  final SupabaseClient client;

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(String email, String password, String name) async {
    await client.auth.signUp(
      email: email,
      password: password,
      // Only a display name; access never depends on user metadata.
      data: {'display_name': name},
      emailRedirectTo: kIsWeb ? '${Uri.base.origin}/' : nativeAuthCallback,
    );
  }
}
