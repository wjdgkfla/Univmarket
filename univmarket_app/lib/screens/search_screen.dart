import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/chip_choice.dart';
import '../widgets/listing_row.dart';
import '../widgets/screen_scaffold.dart';

const _filters = [
  'Under \$50',
  'Near Library Steps',
  'Accepts trades',
  'Like New +',
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  int activeFilter = 0;
  final _controller = TextEditingController(text: 'mini fridge');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<Repository>();
    final all = repo.listListings();
    final results = all.length > 6 ? all.sublist(2, 7) : const <Listing>[];

    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Text(
              'Search',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: c.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: c.line, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 16, color: c.inkFaint),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.inter(color: c.ink, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'mini fridge, calc textbook, bike…',
                        hintStyle: GoogleFonts.inter(
                          color: c.inkFaint,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ChipChoice(
                label: _filters[i],
                active: i == activeFilter,
                onTap: () => setState(() => activeFilter = i),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${results.length} results',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                Text(
                  'Sort: Newest',
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
            child: Column(
              children: [
                for (final l in results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListingRow(listing: l),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
