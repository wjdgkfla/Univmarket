import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/category_art.dart';
import '../widgets/gradient_button.dart';
import '../widgets/pill.dart';

class ListingDetailScreen extends StatelessWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<Repository>();
    final listing = repo.getListing(id);
    if (listing == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox(),
      );
    }
    final saved = repo.favorites.contains(listing.id);
    final topInset = MediaQuery.of(context).padding.top;
    final seller = repo.getSeller(listing.sellerId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 300,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CategoryArt(icon: listing.icon, glyphScale: 1.4),
                      Positioned(
                        left: 14,
                        right: 14,
                        top: topInset + 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _IconBtn(
                              icon: Icons.chevron_left_rounded,
                              label: 'Go back',
                              onTap: () => context.pop(),
                            ),
                            Row(
                              children: [
                                _IconBtn(
                                  icon: saved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: saved ? c.accent : Colors.white,
                                  label: saved
                                      ? 'Remove from saved'
                                      : 'Save listing',
                                  onTap: () => context
                                      .read<Repository>()
                                      .toggleFavorite(listing.id),
                                ),
                                const SizedBox(width: 8),
                                _IconBtn(
                                  icon: Icons.ios_share_rounded,
                                  label: 'Share listing',
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 130),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: c.line,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Text(
                          '\$${listing.price}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          listing.title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            Pill(label: listing.tag, tone: PillTone.accent),
                            Pill(
                              label: listing.condition.label,
                              tone: PillTone.good,
                            ),
                            if (listing.trades)
                              const Pill(label: 'Open to trades'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.surface,
                            border: Border.all(color: c.line),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              Avatar(initials: seller?.initials ?? '?'),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      seller?.name ?? '',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: c.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 14,
                                          color: c.warn,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${seller?.rating ?? 0} · ${seller?.dealsDone ?? 0} completed deals',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: c.inkSoft,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Pill(
                                label: 'Verified .edu',
                                tone: PillTone.good,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Details\n',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                  fontSize: 13.5,
                                ),
                              ),
                              TextSpan(
                                text: listing.description,
                                style: GoogleFonts.inter(
                                  color: c.inkSoft,
                                  fontSize: 13.5,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              size: 15,
                              color: c.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Meet at ${listing.zone}, Fenwick University',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: c.inkSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Listed 2 days ago · 34 views',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: c.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.bg.withValues(alpha: 0), c.bg, c.bg],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openChat(context, repo, listing.id),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.line, width: 1.5),
                        backgroundColor: c.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      child: Text(
                        'Message',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(
                      label: 'Make offer',
                      onPressed: () => _openChat(context, repo, listing.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openChat(
  BuildContext context,
  Repository repo,
  String listingId,
) async {
  final id = await repo.conversationForListing(listingId);
  if (context.mounted) context.push('/chat/$id');
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
