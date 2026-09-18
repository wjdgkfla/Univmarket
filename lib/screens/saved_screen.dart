import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_row.dart';
import '../widgets/screen_scaffold.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final saved = repo
        .listListings()
        .where((l) => repo.favorites.contains(l.id))
        .toList();
    return ScreenScaffold(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved for later',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              saved.isEmpty
                  ? 'Items you save show up here.'
                  : '${saved.length} saved',
            ),
            const SizedBox(height: 24),
            if (saved.isEmpty)
              EmptyState(
                icon: Icons.favorite_border,
                title: 'Nothing saved yet',
                message: 'Tap the heart on any listing to keep an eye on it.',
                actionLabel: 'Browse listings',
                onAction: () => context.go('/'),
              ),
            for (final listing in saved)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListingRow(listing: listing),
              ),
          ],
        ),
      ),
    );
  }
}
