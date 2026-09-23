import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/async_action.dart';
import '../widgets/empty_state.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/pill.dart';
import '../widgets/time_ago.dart';
import 'listing_detail_screen.dart' show dialogAction;

/// Moderator queue: open reports at your university, newest first.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late Future<List<AdminReport>> _reports = context
      .read<Repository>()
      .openReports();

  Future<void> _reload() {
    final next = context.read<Repository>().openReports();
    setState(() {
      _reports = next;
    });
    return next.then((_) {}, onError: (_) {});
  }

  Future<void> _review(AdminReport report) async {
    final canHide = report.listingId != null && !report.listingHidden;
    final canSuspend = report.reportedUserState == 'active';
    final action = await showCupertinoModalPopup<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => CupertinoActionSheet(
        title: Text(reportReasons[report.reason] ?? report.reason),
        message: Text('About ${report.reportedUserName}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheet, 'dismiss'),
            child: const Text('Dismiss report'),
          ),
          if (canHide)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(sheet, 'hide_listing'),
              child: const Text('Hide listing'),
            ),
          if (canSuspend)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(sheet, 'suspend_user'),
              child: Text('Suspend ${report.reportedUserName}'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'suspend_user') {
      final confirmed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog.adaptive(
          title: Text('Suspend ${report.reportedUserName}?'),
          content: const Text(
            'They are signed out of the market, all their listings are hidden, and every open report about them is closed.',
          ),
          actions: [
            dialogAction(dialog, 'Cancel', () => Navigator.pop(dialog, false)),
            dialogAction(
              dialog,
              'Suspend',
              () => Navigator.pop(dialog, true),
              primary: true,
              destructive: true,
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await context.read<Repository>().resolveReport(report.id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            'hide_listing' => 'Listing hidden.',
            'suspend_user' => '${report.reportedUserName} is suspended.',
            _ => 'Report dismissed.',
          }),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _reload,
        child: FutureBuilder<List<AdminReport>>(
          future: _reports,
          builder: (context, snapshot) {
            final Widget body;
            if (snapshot.connectionState != ConnectionState.done) {
              body = const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            } else if (snapshot.hasError) {
              body = EmptyState(
                icon: CupertinoIcons.exclamationmark_circle,
                title: 'Could not load reports',
                message: friendlyError(snapshot.error!),
                actionLabel: 'Try again',
                onAction: _reload,
              );
            } else if (snapshot.data!.isEmpty) {
              body = const EmptyState(
                icon: CupertinoIcons.checkmark_shield,
                title: 'No open reports',
                message:
                    'New reports from students at your school show up here.',
              );
            } else {
              final reports = snapshot.data!;
              body = Column(
                children: [
                  for (var i = 0; i < reports.length; i++) ...[
                    if (i > 0) Divider(indent: gutter, color: c.line),
                    FadeSlideIn(
                      key: ValueKey(reports[i].id),
                      index: i,
                      child: _ReportRow(
                        report: reports[i],
                        onTap: () => _review(reports[i]),
                      ),
                    ),
                  ],
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [body],
            );
          },
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.onTap});
  final AdminReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final date = report.createdAt;
    final meta = TextStyle(fontSize: 13, color: c.inkSoft, height: 1.35);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    reportReasons[report.reason] ?? report.reason,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
                if (date != null) Text(timeAgo(date), style: meta),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              report.listingTitle != null
                  ? 'Listing: ${report.listingTitle}'
                  : 'About the student',
              style: TextStyle(fontSize: 15, color: c.ink),
            ),
            const SizedBox(height: 4),
            Text(
              '${report.reportedUserName}'
              '${report.openReportsOnUser > 1 ? ' · ${report.openReportsOnUser} open reports' : ''}'
              ' · reported by ${report.reporterName}',
              style: meta,
            ),
            if (report.notes != null) ...[
              const SizedBox(height: 6),
              Text('"${report.notes}"', style: meta),
            ],
            if (report.listingHidden || report.reportedUserState != 'active')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (report.listingHidden)
                      const Pill(
                        label: 'listing hidden',
                        tone: PillTone.neutral,
                      ),
                    if (report.reportedUserState != 'active')
                      Pill(label: report.reportedUserState, tone: PillTone.bad),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
