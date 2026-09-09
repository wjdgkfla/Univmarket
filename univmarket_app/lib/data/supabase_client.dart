import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> initSupabase() async {
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    throw StateError(
      'Live mode requires SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
    );
  }
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
}

SupabaseClient get supabase => Supabase.instance.client;
