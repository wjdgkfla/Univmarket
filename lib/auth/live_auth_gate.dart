import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app.dart';
import '../data/repository.dart';
import '../screens/auth_screen.dart';
import '../screens/password_recovery_screen.dart';
import 'auth_service.dart';
import 'auth_browser_location.dart';
import 'recovery_service.dart';

class LiveAuthGate extends StatefulWidget {
  const LiveAuthGate({
    super.key,
    required this.client,
    this.initialLink,
    this.linkStream,
    this.browserLocation,
  });
  final SupabaseClient client;
  final Future<Uri?> Function()? initialLink;
  final Stream<Uri>? linkStream;
  final AuthBrowserLocation? browserLocation;
  @override
  State<LiveAuthGate> createState() => _LiveAuthGateState();
}

class _LiveAuthGateState extends State<LiveAuthGate> {
  StreamSubscription<AuthState>? _subscription;
  StreamSubscription<Uri>? _links;
  late final AuthBrowserLocation? _browser =
      widget.browserLocation ?? (kIsWeb ? AuthBrowserLocation() : null);
  Repository? _repository;
  UnivMarketApp? _app;
  String? _userId;
  bool _initializing = true;
  bool _processingLink = false;
  bool _recovering = false;
  String? _linkError;
  String? _lastLink;
  Future<void> _linkQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _subscription = widget.client.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          if (state.event == AuthChangeEvent.passwordRecovery) {
            _recovering = true;
          }
          if (state.event == AuthChangeEvent.signedOut) _recovering = false;
          _syncSession();
        });
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _clearRepository();
            _linkError =
                'Your session could not be restored. Please sign in again.';
          });
        }
      },
    );
    _initializeLinks();
  }

  Future<void> _initializeLinks() async {
    try {
      _links = (widget.linkStream ?? AppLinks().uriLinkStream).listen(
        (uri) => unawaited(_enqueueLink(uri)),
        onError: (Object _) {
          if (mounted) {
            setState(
              () => _linkError =
                  'Unable to open the account link. Request a new link and try again.',
            );
          }
        },
      );
      final initial =
          await (widget.initialLink?.call() ??
              (_browser != null
                  ? Future.value(_browser.read())
                  : AppLinks().getInitialLink()));
      if (!mounted) return;
      if (initial != null) await _enqueueLink(initial);
      if (!mounted) return;
    } catch (_) {
      if (mounted) {
        setState(
          () => _linkError =
              'Unable to open the account link. Request a new link and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
          _syncSession();
        });
      }
    }
  }

  Future<void> _enqueueLink(Uri uri) {
    _linkQueue = _linkQueue.then((_) => _handleLink(uri));
    return _linkQueue;
  }

  Future<void> _handleLink(Uri uri) async {
    final parameters = <String>{...uri.queryParameters.keys};
    try {
      parameters.addAll(Uri.splitQueryString(uri.fragment).keys);
    } on FormatException {
      return;
    }
    if (!parameters.any(
      {
        'code',
        'access_token',
        'error',
        'error_description',
        'error_code',
      }.contains,
    )) {
      return;
    }
    final native =
        uri.scheme == 'com.univmarket.app' &&
        uri.host == 'auth-callback' &&
        uri.path == '/';
    final web =
        _browser != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.origin == _browser.read().origin &&
        uri.path == '/';
    if ((!native && !web) ||
        (!uri.hasQuery && !uri.hasFragment) ||
        _lastLink == uri.toString() ||
        !mounted) {
      return;
    }
    setState(() {
      _processingLink = true;
      _linkError = null;
      _clearRepository();
    });
    try {
      final response = await widget.client.auth.getSessionFromUrl(uri);
      _lastLink = uri.toString();
      if (mounted &&
          (response.redirectType == 'recovery' ||
              response.redirectType == 'passwordRecovery')) {
        _recovering = true;
      }
      if (web) await _browser.finishCallback(recovering: _recovering);
    } catch (_) {
      if (mounted) {
        _linkError =
            'This account link is invalid or expired. Request a new link and open it on this device.';
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingLink = false;
          _syncSession();
        });
      }
    }
  }

  void _clearRepository() {
    _repository?.removeListener(_changed);
    _repository?.dispose();
    _repository = null;
    _app = null;
    _userId = null;
  }

  void _syncSession() {
    if (_browser?.recoveryRequested == true &&
        widget.client.auth.currentSession != null) {
      _recovering = true;
    }
    if (_initializing || _processingLink || _recovering || _linkError != null) {
      _clearRepository();
      return;
    }
    final user = widget.client.auth.currentUser;
    final id =
        user != null && !user.isAnonymous && user.emailConfirmedAt != null
        ? user.id
        : null;
    if (id == _userId) return;
    _clearRepository();
    if (id != null) {
      _userId = id;
      _repository = Repository(client: widget.client)..addListener(_changed);
      _app = UnivMarketApp(key: ValueKey(id), repository: _repository);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _signOut() =>
      widget.client.auth.signOut(scope: SignOutScope.local);
  @override
  void dispose() {
    _subscription?.cancel();
    _links?.cancel();
    _clearRepository();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repository;
    if (repo != null && repo.ready && repo.bootstrapError == null) return _app!;
    Widget home;
    if (_initializing || _processingLink) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_recovering) {
      home = PasswordRecoveryScreen(
        service: SupabaseRecoveryService(widget.client),
        resetSession: true,
        onFinished: _signOut,
      );
    } else if (_linkError != null) {
      home = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_linkError!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: () async {
                    try {
                      await _signOut();
                      if (mounted) setState(() => _linkError = null);
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _linkError =
                              'Unable to sign out. Check your connection and retry.',
                        );
                      }
                    }
                  },
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (repo == null) {
      home = AuthScreen(
        auth: SupabaseAuthService(widget.client),
        recovery: SupabaseRecoveryService(widget.client),
      );
    } else {
      home = Scaffold(
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
                            await _signOut();
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => _linkError =
                                    'Unable to sign out. Check your connection and retry.',
                              );
                            }
                          }
                        },
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBD431D)),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
