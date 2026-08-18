import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/listing_tile.dart';
import '../widgets/screen_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<Repository>();
    final me = repo.me;

    final stats = [
      (num: me.rating.toStringAsFixed(1), label: 'Rating'),
      (num: '${me.dealsDone}', label: 'Deals done'),
      (num: '${me.meetupsKeptPct}%', label: 'Meetups kept'),
      (num: me.avgReplyTime, label: 'Avg. reply time'),
    ];

    final mine = repo.listListings().where((l) => l.sellerId == me.id).toList();

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Semantics(
              button: true,
              label: 'Go back',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: c.ink,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
              child: Column(
                children: [
                  Avatar(initials: me.initials, size: 68),
                  const SizedBox(height: 12),
                  Text(
                    me.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    me.school,
                    style: GoogleFonts.inter(fontSize: 12.5, color: c.inkSoft),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.accentWash,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 11, color: c.accentDeep),
                        const SizedBox(width: 5),
                        Text(
                          'DEMO MODE PROFILE',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: c.accentDeep,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in stats)
                  Container(
                    width: (MediaQuery.of(context).size.width - 36 - 10) / 2,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.line),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.num,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: c.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active listings',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                Text(
                  'Manage',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final l in mine)
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 36 - 10) / 2,
                    child: ListingTile(listing: l),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
