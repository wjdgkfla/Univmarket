// Manual QA entrypoint only. Never use this target for release builds.
// All writes stay in browser-local test storage; no Supabase client is created.
import 'package:flutter/widgets.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(UnivMarketApp(repository: await DemoRepository.open()));
}
