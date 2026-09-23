import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../screens/listing_detail_screen.dart' show dialogAction;
import 'async_action.dart';

/// "More" menu about another student: report them (or [listingId]), or
/// block them. Blocking returns to Home, since their content disappears.
Future<void> showSafetyMenu(
  BuildContext context, {
  required String userId,
  required String userName,
  String? listingId,
}) async {
  final repo = context.read<Repository>();
  final choice = await showCupertinoModalPopup<String>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet, 'report'),
          child: Text(
            listingId == null ? 'Report $userName' : 'Report listing',
          ),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(sheet, 'block'),
          child: Text('Block $userName'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheet),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (!context.mounted) return;

  if (choice == 'report') {
    final reason = await showCupertinoModalPopup<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => CupertinoActionSheet(
        title: const Text('Why are you reporting this?'),
        message: const Text('Reports are private. The student is not told.'),
        actions: [
          for (final entry in reportReasons.entries)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheet, entry.key),
              child: Text(entry.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await repo.report(userId: userId, listingId: listingId, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thanks for letting us know. We review every report.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
    return;
  }

  if (choice == 'block') {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog.adaptive(
        title: Text('Block $userName?'),
        content: const Text(
          'You won\'t see their listings or messages, and they can\'t message you or make offers. You can unblock them from your profile.',
        ),
        actions: [
          dialogAction(dialog, 'Cancel', () => Navigator.pop(dialog, false)),
          dialogAction(
            dialog,
            'Block',
            () => Navigator.pop(dialog, true),
            primary: true,
            destructive: true,
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await repo.block(userId);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/');
      messenger.showSnackBar(SnackBar(content: Text('$userName is blocked.')));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
