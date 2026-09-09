import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app.dart';
import '../data/repository.dart';
import '../screens/auth_screen.dart';
import 'auth_service.dart';

/// Owns a fresh repository per confirmed user, so sign-out discards cached data.
class LiveAuthGate extends StatefulWidget {
  const LiveAuthGate({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<LiveAuthGate> createState() => _LiveAuthGateState();
}

class _LiveAuthGateState extends State<LiveAuthGate> {
  StreamSubscription<AuthState>? _subscription;
  Repository? _repository;
  UnivMarketApp? _app;
  String? _userId;
  @override
  void initState() {
    super.initState();
    _syncSession();
    _subscription = widget.client.auth.onAuthStateChange.listen(
      (_) {
        if (mounted) setState(_syncSession);
      },
      onError: (Object _) {
        if (mounted) setState(_clearRepository);
      },
    );
  }

  void _clearRepository() {
    _repository?.removeListener(_changed);
    _repository?.dispose();
    _repository = null;
    _app = null;
    _userId = null;
  }

  void _syncSession() {
    final user = widget.client.auth.currentUser;
    final id =
        user != null && !user.isAnonymous && user.emailConfirmedAt != null
        ? user.id
        : null;
    if (id == _userId) return;
    _clearRepository();
    if (id != null) {
      _userId = id;
      _repository = Repository()..addListener(_changed);
      _app = UnivMarketApp(key: ValueKey(id), repository: _repository);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _clearRepository();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repository;
    if (repo != null && repo.ready && repo.bootstrapError == null) {
      return _app!;
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBD431D)),
        useMaterial3: true,
      ),
      home: repo == null
          ? AuthScreen(auth: SupabaseAuthService(widget.client))
          : Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: !repo.ready
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Unable to load your marketplace. Your account may need university access, or the connection may be unavailable.',
                              textAlign: TextAlign.center,
                            ),
                            FilledButton(
                              onPressed: () => setState(() {
                                _clearRepository();
                                _syncSession();
                              }),
                              child: const Text('Retry'),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await widget.client.auth.signOut(
                                    scope: SignOutScope.local,
                                  );
                                } catch (_) {}
                              },
                              child: const Text('Back to sign in'),
                            ),
                          ],
                        ),
                ),
              ),
            ),
    );
  }
}
