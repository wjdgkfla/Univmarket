import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/repository.dart';

/// Registers this phone for pushes and opens the chat a tapped push is about.
/// Without Firebase config (web, or before `flutterfire configure`) it does
/// nothing and the app works as before; the inbox still refreshes itself.
class PushNotifications extends StatefulWidget {
  const PushNotifications({
    super.key,
    required this.repository,
    required this.router,
    required this.child,
  });
  final Repository repository;
  final GoRouter router;
  final Widget child;
  @override
  State<PushNotifications> createState() => _PushNotificationsState();
}

class _PushNotificationsState extends State<PushNotifications> {
  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && !widget.repository.isDemo) unawaited(_setUp());
  }

  String? get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  };

  Future<void> _setUp() async {
    final platform = _platform;
    if (platform == null) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Push disabled: Firebase is not configured ($e)');
      return;
    }
    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // iOS shows the banner even while the app is open; Android gets the
      // in-app snackbar below instead.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: true,
      );
      if (!mounted) return;
      _subscriptions
        ..add(messaging.onTokenRefresh.listen(_register))
        ..add(FirebaseMessaging.onMessage.listen(_onForeground))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_open));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial);
      final token = await messaging.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  Future<void> _register(String token) async {
    final platform = _platform;
    if (platform == null) return;
    try {
      await widget.repository.registerPushToken(token, platform: platform);
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }

  String? _link(RemoteMessage message) {
    final link = message.data['link'];
    return link is String && link.startsWith('/chat/') ? link : null;
  }

  void _open(RemoteMessage message) {
    final link = _link(message);
    if (link == null || !mounted) return;
    if (widget.router.routerDelegate.currentConfiguration.uri.path != link) {
      widget.router.push(link);
    }
  }

  void _onForeground(RemoteMessage message) {
    unawaited(widget.repository.refreshInbox().catchError((Object _) {}));
    final link = _link(message);
    final note = message.notification;
    if (!mounted || note == null) return;
    // Already reading that chat: its own sync shows the new message.
    if (widget.router.routerDelegate.currentConfiguration.uri.path == link) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          [note.title, note.body].whereType<String>().join(': '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        action: link == null
            ? null
            : SnackBarAction(label: 'View', onPressed: () => _open(message)),
      ),
    );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
