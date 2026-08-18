import 'package:supabase_flutter/supabase_flutter.dart';

/// Publishable (anon-safe) key — RLS enforces all real security, so this is
/// safe to embed client-side.
const _supabaseUrl = 'https://amzvnsphtaxkjzmsjsie.supabase.co';
const _supabaseAnonKey = 'sb_publishable_ACllYW7hhMR1_ORSMvx0OA_skxkyVJW';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
