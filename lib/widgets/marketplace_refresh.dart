import 'dart:async';
import 'package:flutter/material.dart';
import '../data/repository.dart';

/// Refresh signed photo URLs before expiry and reload the catalog on resume.
class MarketplaceRefresh extends StatefulWidget {
  const MarketplaceRefresh({
    super.key,
    required this.repository,
    required this.child,
    this.interval = const Duration(minutes: 45),
  });
  final Repository repository;
  final Widget child;
  final Duration interval;
  @override
  State<MarketplaceRefresh> createState() => _MarketplaceRefreshState();
}

class _MarketplaceRefreshState extends State<MarketplaceRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _failed = false;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.repository.isDemo) return;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      await widget.repository.refreshMarketplace();
      if (mounted && _failed) setState(() => _failed = false);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(_refresh());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_failed)
        MaterialBanner(
          content: const Text(
            'Could not refresh the marketplace. Your previous results are still shown.',
          ),
          actions: [
            TextButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      Expanded(child: widget.child),
    ],
  );
}
