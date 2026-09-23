import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'recovery_service.dart';

abstract interface class AuthService {
  Future<void> signIn(String email, String password);

  /// [name] becomes the profile's display name on first sign-in.
  Future<void> signUp(String email, String password, String name);

  /// Confirms the 6-digit code emailed at sign-up and starts the session.
  Future<void> confirmSignUp(String email, String code);

  /// Emails a fresh code for a still-unconfirmed sign-up.
  Future<void> resendSignUpCode(String email);
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

  @override
  Future<void> confirmSignUp(String email, String code) async {
    await client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: code,
    );
  }

  @override
  Future<void> resendSignUpCode(String email) async {
    await client.auth.resend(type: OtpType.signup, email: email);
  }
}
