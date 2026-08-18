import 'package:flutter/material.dart';
import 'app.dart';
import 'data/repository.dart';
import 'data/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const AuthGate());
}

/// Shown while the initial anonymous-auth + profile-bootstrap is in flight.
/// Kicks the bootstrap off once in initState (not from build/FutureBuilder —
/// see Repository's doc comment on why this codebase avoids that pattern)
/// and rebuilds via setState only when Repository's own notifyListeners()
/// fires with ready == true.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Repository _repository;

  @override
  void initState() {
    super.initState();
    _repository = Repository();
    _repository.addListener(_onRepositoryChanged);
  }

  void _onRepositoryChanged() {
    if (_repository.ready && mounted) setState(() {});
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_repository.ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (_repository.bootstrapError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not connect: ${_repository.bootstrapError}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    return UnivMarketApp(repository: _repository);
  }
}
