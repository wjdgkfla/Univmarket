import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/async_action.dart';
import '../widgets/avatar.dart';
import '../widgets/legal_links.dart';
import '../widgets/listing_row.dart';
import 'auth_screen.dart' show validDisplayName;
import 'listing_detail_screen.dart' show dialogAction;

Future<void> _editName(BuildContext context, Repository repo) async {
  final name = await showAdaptiveDialog<String>(
    context: context,
    builder: (_) => _NameDialog(initial: repo.me.name),
  );
  if (name != null && name != repo.me.name && context.mounted) {
    await runAction(context, () => repo.updateDisplayName(name));
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final error = validDisplayName(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog.adaptive(
    title: const Text('Your name'),
    content: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            helperText: 'Shown to other students on your listings.',
            errorText: _error,
          ),
        ),
      ),
    ),
    actions: [
      dialogAction(context, 'Cancel', () => Navigator.pop(context)),
      dialogAction(context, 'Save', _save, primary: true),
    ],
  );
}

Future<void> _confirmDelete(BuildContext context, Repository repo) async {
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog.adaptive(
      title: const Text('Delete your account?'),
      content: const Text(
        'Your listings, saved items and sign-in are removed, open offers are withdrawn, and reservations are cancelled. '
        'Past messages stay with the other student, shown as from "Deleted student". This can\'t be undone.',
      ),
      actions: [
        dialogAction(dialog, 'Cancel', () => Navigator.pop(dialog, false)),
        dialogAction(
          dialog,
          'Delete account',
          () => Navigator.pop(dialog, true),
          primary: true,
          destructive: true,
        ),
      ],
    ),
  );
  // Success signs out, and the app returns to the sign-in screen.
  if (confirmed == true && context.mounted) {
    await runAction(context, repo.deleteAccount);
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = context.colors;
    final mine = repo
        .listListings()
        .where((l) => l.sellerId == repo.me.id)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 20, gutter, 20),
            child: Row(
              children: [
                Avatar(initials: repo.me.initials, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              repo.me.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: c.ink,
                              ),
                            ),
                          ),
                          if (!repo.isDemo)
                            IconButton(
                              tooltip: 'Edit name',
                              icon: Icon(
                                CupertinoIcons.pencil,
                                size: 20,
                                color: c.inkSoft,
                              ),
                              onPressed: () => _editName(context, repo),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (!repo.isDemo) ...[
                            Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              size: 15,
                              color: c.accent,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              repo.me.school,
                              style: TextStyle(fontSize: 14, color: c.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 8, color: c.surface2),
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 16, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Your listings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/sell'),
                  child: const Text('Add new'),
                ),
              ],
            ),
          ),
          if (mine.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 28),
              child: Text(
                'Your next listing starts here. Sell something you no longer need.',
                style: TextStyle(fontSize: 15, height: 1.45, color: c.inkSoft),
              ),
            ),
          ListingRows(listings: mine),
          if (repo.blocked.isNotEmpty) ...[
            Container(height: 8, color: c.surface2),
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 16, gutter, 4),
              child: Text(
                'Blocked students',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ),
            for (final id in repo.blocked)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: gutter),
                leading: Avatar(
                  initials: repo.getSeller(id)?.initials ?? '?',
                  size: 40,
                ),
                title: Text(repo.getSeller(id)?.name ?? 'Student'),
                trailing: TextButton(
                  onPressed: () => runAction(context, () => repo.unblock(id)),
                  child: const Text('Unblock'),
                ),
              ),
          ],
          if (repo.isAdmin) ...[
            Container(height: 8, color: c.surface2),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: gutter),
              leading: Icon(CupertinoIcons.checkmark_shield, color: c.ink),
              title: const Text(
                'Review reports',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (repo.openReportCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.bad,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${repo.openReportCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(CupertinoIcons.chevron_forward, color: c.inkFaint),
                ],
              ),
              onTap: () => context.push('/admin/reports'),
            ),
          ],
          Container(height: 8, color: c.surface2),
          for (final (icon, label, url) in [
            (CupertinoIcons.lock_shield, 'Privacy Policy', privacyUrl),
            (CupertinoIcons.doc_text, 'Terms of Use', termsUrl),
            (
              CupertinoIcons.envelope,
              'Contact support',
              'mailto:$supportEmail',
            ),
          ])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: gutter),
              leading: Icon(icon, color: c.ink),
              title: Text(label),
              trailing: Icon(CupertinoIcons.chevron_forward, color: c.inkFaint),
              onTap: () => openLegalLink(context, url),
            ),
          if (!repo.isDemo) ...[
            Container(height: 8, color: c.surface2),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: gutter),
              leading: Icon(CupertinoIcons.square_arrow_right, color: c.bad),
              title: Text(
                'Sign out',
                style: TextStyle(color: c.bad, fontWeight: FontWeight.w600),
              ),
              onTap: () => runAction(context, repo.signOut),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: gutter),
              leading: Icon(CupertinoIcons.trash, color: c.bad),
              title: Text(
                'Delete account',
                style: TextStyle(color: c.bad, fontWeight: FontWeight.w600),
              ),
              onTap: () => _confirmDelete(context, repo),
            ),
          ],
          const SizedBox(height: 20),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(
              snapshot.hasData
                  ? 'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                  : '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: c.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}
