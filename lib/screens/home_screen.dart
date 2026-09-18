import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_tile.dart';
import '../widgets/screen_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String category = 'All';
  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = context.colors;
    final items = repo
        .listListings()
        .where(
          (l) =>
              l.status == 'available' &&
              (category == 'All' || l.tag == category),
        )
        .toList();
    return ScreenScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.school_outlined, color: c.accent, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    marketName(repo.schoolShortName),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/profile'),
                  tooltip: 'Your profile',
                  icon: const Icon(Icons.account_circle_outlined, size: 30),
                ),
              ],
            ),
            // Fixed by the account's email domain; there is no market switcher.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                repo.me.school,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (repo.isDemo)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.accentWash,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'LOCAL DEMO · Sample listings. Changes stay on this device.',
                  style: TextStyle(color: c.inkSoft, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Good finds.\nRight on campus.',
              style: TextStyle(
                fontSize: 34,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Give your things a second semester.',
              style: TextStyle(color: c.inkSoft, fontSize: 15),
            ),
            const SizedBox(height: 22),
            InkWell(
              onTap: () => context.go('/search'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: c.inkSoft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'What are you looking for?',
                        style: TextStyle(color: c.inkSoft),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final label in ['All', ...categories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: category == label,
                        onSelected: (_) => setState(() => category = label),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fresh on campus',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${items.length} finds',
                  style: TextStyle(color: c.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              category == 'All'
                  ? EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Be the first to sell here',
                      message:
                          'Post something you no longer need and it will show up for everyone at ${repo.me.school}.',
                      actionLabel: 'Post a listing',
                      onAction: () => context.go('/sell'),
                    )
                  : EmptyState(
                      icon: Icons.search_off,
                      title: 'No $category yet',
                      message: 'Try another category or check back soon.',
                      actionLabel: 'Show all',
                      onAction: () => setState(() => category = 'All'),
                    ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 650 ? 3 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: width,
                        child: ListingTile(listing: item),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
