import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'auth/live_auth_gate.dart';
import 'data/supabase_client.dart';
import 'widgets/version_gate.dart';

SemanticsHandle? accessibilityHandle;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  accessibilityHandle = SemanticsBinding.instance.ensureSemantics();
  runApp(const Startup());
}

class Startup extends StatefulWidget {
  const Startup({super.key});
  @override
  State<Startup> createState() => _StartupState();
}

class _StartupState extends State<Startup> {
  bool _initialized = false;
  int? _build;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await initSupabase();
      _build = await PackageInfo.fromPlatform()
          .then((info) => int.tryParse(info.buildNumber))
          .catchError((Object _) => null);
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to open the marketplace. Check your connection or backend configuration, then retry.',
        );
      }
    }
  }

  Future<MinimumVersion?> _fetchMinimum() async {
    final row = await supabase
        .from('app_config')
        .select('min_build, update_url')
        .maybeSingle();
    return row == null
        ? null
        : (
            minBuild: row['min_build'] as int,
            updateUrl: row['update_url'] as String?,
          );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return VersionGate(
        build: _build,
        fetchMinimum: _fetchMinimum,
        child: LiveAuthGate(client: supabase),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'Could not open UnivMarket',
                        style: TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
