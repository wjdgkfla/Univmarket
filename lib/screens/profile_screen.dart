import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../data/supabase_client.dart';
import '../theme/tokens.dart';
import '../widgets/async_action.dart';
import '../widgets/avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/listing_row.dart';
import 'listing_detail_screen.dart' show dialogAction;

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
                      Text(
                        repo.me.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: c.ink,
                        ),
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
          if (!repo.isDemo) ...[
            Container(height: 8, color: c.surface2),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: gutter),
              leading: Icon(CupertinoIcons.square_arrow_right, color: c.bad),
              title: Text(
                'Sign out',
                style: TextStyle(color: c.bad, fontWeight: FontWeight.w600),
              ),
              onTap: () => runAction(
                context,
                () => supabase.auth.signOut(scope: SignOutScope.local),
              ),
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
