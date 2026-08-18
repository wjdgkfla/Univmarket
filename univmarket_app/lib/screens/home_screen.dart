import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/category_art.dart';
import '../widgets/listing_tile.dart';
import '../widgets/screen_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<Repository>();
    final listings = repo.listListings();
    final featured = listings.length > 1 ? listings[1] : null;
    final gridItems = listings.length > 6
        ? listings.sublist(2, 6)
        : const <Listing>[];

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Univ',
                        style: GoogleFonts.spaceGrotesk(
                          color: c.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      TextSpan(
                        text: 'Market',
                        style: GoogleFonts.spaceGrotesk(
                          color: c.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Avatar(
                  initials: repo.me.initials,
                  onTap: () => context.push('/profile'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => context.push('/search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: c.line, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 16, color: c.inkFaint),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Search textbooks, dorm gear, bikes…',
                          style: GoogleFonts.inter(
                            color: c.inkFaint,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                if (featured != null) _FeaturedCard(listing: featured),
                const SizedBox(height: 10),
                _SellCta(),
                const SizedBox(height: 10),
                _TrustStat(),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final l in gridItems)
                      SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 36 - 10) / 2,
                        child: ListingTile(listing: l),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Listing listing;
  const _FeaturedCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/listing/${listing.id}'),
        child: SizedBox(
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CategoryArt(icon: listing.icon, glyphScale: 1.6),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xD9160814),
                      Color(0x2E781E3C),
                      Colors.transparent,
                    ],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FEATURED NEAR YOU',
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFFFFCBB8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listing.title,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${listing.price}',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/sell'),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.accent, c.accentDeep]),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Got stuff to sell?',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'List it in under a minute — photo, price, done.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustStat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.goodWash,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.trending_up_rounded, size: 18, color: c.good),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '128 trades',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: c.ink,
                ),
              ),
              Text(
                'on Fenwick this week',
                style: GoogleFonts.inter(fontSize: 11.5, color: c.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
