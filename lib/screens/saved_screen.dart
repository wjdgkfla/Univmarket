import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_row.dart';
import '../widgets/screen_scaffold.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = context.colors;
    final saved = repo
        .listListings()
        .where((l) => repo.favorites.contains(l.id))
        .toList();
    return ScreenScaffold(
      title: 'Saved for later',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (saved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 4),
              child: Text(
                saved.length == 1
                    ? '1 saved item'
                    : '${saved.length} saved items',
                style: TextStyle(fontSize: 14, color: c.inkSoft),
              ),
            ),
          if (saved.isEmpty)
            EmptyState(
              icon: CupertinoIcons.heart,
              title: 'Nothing saved yet',
              message: 'Tap the heart on any listing to keep an eye on it.',
              actionLabel: 'Browse listings',
              onAction: () => context.go('/'),
            ),
          ListingRows(listings: saved),
        ],
      ),
    );
  }
}
