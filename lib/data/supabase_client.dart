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
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
  );
  _initialized = true;
}

SupabaseClient get supabase => Supabase.instance.client;
