import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/brand_mark.dart';
import '../widgets/category_chip.dart';
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
    final market = marketName(repo.schoolShortName);
    final bottomPad =
        ScreenScaffold.navClearanceHeight +
        MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 64,
            titleSpacing: gutter,
            centerTitle: false,
            shape: const Border(),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandMark(size: 22, color: c.accent),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        market,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                // Fixed by the account's email domain; there is no switcher.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      size: 13,
                      color: c.accent,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        repo.me.school,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: c.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              Tooltip(
                message: 'Your profile',
                child: InkResponse(
                  onTap: () => context.push('/profile'),
                  radius: 24,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Avatar(initials: repo.me.initials, size: 34),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                padding: const EdgeInsets.fromLTRB(gutter, 2, gutter, 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.line, width: 0.5)),
                ),
                child: _SearchPrompt(
                  hint: 'Search $market',
                  onTap: () => context.go('/search'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: gutter),
                  child: Row(
                    children: [
                      for (final label in ['All', ...categories])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CategoryChip(
                            label: label,
                            selected: category == label,
                            onTap: () => setState(() => category = label),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Fresh on campus',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: c.ink,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        items.length == 1
                            ? '1 listing'
                            : '${items.length} listings',
                        style: TextStyle(color: c.inkSoft, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  category == 'All'
                      ? EmptyState(
                          icon: CupertinoIcons.bag,
                          title: 'Be the first to sell here',
                          message:
                              'Post something you no longer need and it will show up for everyone at ${repo.me.school}.',
                          actionLabel: 'Post a listing',
                          onAction: () => context.go('/sell'),
                        )
                      : EmptyState(
                          icon: CupertinoIcons.search,
                          title: 'No $category yet',
                          message: 'Try another category or check back soon.',
                          actionLabel: 'Show all',
                          onAction: () => setState(() => category = 'All'),
                        ),
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottomPad),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 650 ? 3 : 2;
                      const gap = 12.0;
                      final width =
                          (constraints.maxWidth - (columns - 1) * gap) /
                          columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: 22,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable search field that opens the Search tab.
class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt({required this.hint, required this.onTap});
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      child: Material(
        color: c.surface2,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(CupertinoIcons.search, size: 18, color: c.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.inkSoft, fontSize: 15.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
