import 'dart:async';
import 'package:flutter/material.dart';
import '../data/repository.dart';

/// For moderators only: polls the open report count while the app is in the
/// foreground and shows "New report to review" when it goes up. Reports
/// already open at launch show as badges, not as an alert.
class ReportAlerts extends StatefulWidget {
  const ReportAlerts({
    super.key,
    required this.repository,
    required this.onReview,
    required this.child,
    this.interval = const Duration(minutes: 2),
  });
  final Repository repository;
  final VoidCallback onReview;
  final Widget child;
  final Duration interval;
  @override
  State<ReportAlerts> createState() => _ReportAlertsState();
}

class _ReportAlertsState extends State<ReportAlerts>
    with WidgetsBindingObserver {
  Timer? _timer;
  late int _seen = widget.repository.openReportCount;

  bool get _active => widget.repository.isAdmin && !widget.repository.isDemo;

  @override
  void initState() {
    super.initState();
    if (!_active) return;
    widget.repository.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => unawaited(_poll()));
  }

  Future<void> _poll() async {
    try {
      await widget.repository.refreshReportCount();
    } catch (_) {
      // A missed poll just waits for the next one.
    }
  }

  void _changed() {
    final count = widget.repository.openReportCount;
    final grew = count > _seen;
    _seen = count;
    if (!grew || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: const Text('New report to review'),
        action: SnackBarAction(label: 'Review', onPressed: widget.onReview),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(_poll());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_active) {
      widget.repository.removeListener(_changed);
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
