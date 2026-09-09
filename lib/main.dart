import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'app.dart';
import 'auth/live_auth_gate.dart';
import 'data/demo_repository.dart';
import 'data/repository.dart';
import 'data/supabase_client.dart';

const liveMode = bool.fromEnvironment('LIVE_BACKEND', defaultValue: false);
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
  Repository? _repository;
  bool _liveInitialized = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      if (liveMode) {
        await initSupabase();
        if (mounted) setState(() => _liveInitialized = true);
      } else {
        final repo = await DemoRepository.open();
        if (!mounted) {
          repo.dispose();
          return;
        }
        setState(() => _repository = repo);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to open the marketplace. Check storage permissions or your backend configuration, then retry.',
        );
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _repository?.removeListener(_changed);
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_liveInitialized) return LiveAuthGate(client: supabase);
    if (_repository?.ready == true && _repository?.bootstrapError == null) {
      return UnivMarketApp(repository: _repository!);
    }
    final error = _error ?? _repository?.bootstrapError;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: error == null
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
                      Text(
                        _error ??
                            'The live backend is unavailable. Check your configuration.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          _repository?.removeListener(_changed);
                          _repository?.dispose();
                          _repository = null;
                          _load();
                        },
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
