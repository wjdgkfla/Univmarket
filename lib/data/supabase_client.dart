import 'package:flutter/foundation.dart';
import '../auth/secure_auth_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend_config.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
bool _initialized = false;

Future<void> initSupabase() async {
  if (_initialized) return;
  final config = BackendConfig.validate(
    url: _supabaseUrl,
    publishableKey: _supabaseKey,
  );
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final protectedStore = mobile
      ? SecureAuthStore(
          sessionKey:
              'sb-${Uri.parse(config.url).host.split('.').first}-auth-token',
        )
      : null;
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    authOptions: FlutterAuthClientOptions(
      detectSessionInUri: false,
      localStorage: protectedStore,
      pkceAsyncStorage: protectedStore == null
          ? null
          : SecurePkceStorage(protectedStore),
    ),
  );
  _initialized = true;
}

SupabaseClient get supabase => Supabase.instance.client;
