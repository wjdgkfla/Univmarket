import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/chip_choice.dart';
import '../widgets/listing_tile.dart';
import '../widgets/screen_scaffold.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<Repository>();
    final all = repo.listListings();
    final saved = all.where((l) => repo.favorites.contains(l.id)).toList();

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Text(
              'Saved',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ),
          if (saved.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 90),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 34,
                    color: c.inkFaint,
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      'Nothing saved yet.\nTap the heart on a listing to keep track of it here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: c.inkFaint,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  ChipChoice(label: 'All (${saved.length})', active: true),
                  const SizedBox(width: 8),
                  const ChipChoice(label: 'Textbooks'),
                  const SizedBox(width: 8),
                  const ChipChoice(label: 'Electronics'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final l in saved)
                    SizedBox(
                      width: (MediaQuery.of(context).size.width - 36 - 10) / 2,
                      child: ListingTile(listing: l),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
