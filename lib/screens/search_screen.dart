import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import '../widgets/category_chip.dart';
import '../widgets/listing_row.dart';
import '../widgets/screen_scaffold.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String query = '', sort = 'Newest';
  bool under50 = false, likeNew = false, free = false;
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _resetSearch() {
    _queryController.clear();
    setState(() {
      query = '';
      under50 = likeNew = free = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = context
        .watch<Repository>()
        .listListings()
        .where(
          (l) =>
              l.status == 'available' &&
              ('${l.title} ${l.description} ${l.tag}').toLowerCase().contains(
                query.trim().toLowerCase(),
              ) &&
              (!under50 || l.price < 50) &&
              (!free || l.price == 0) &&
              (!likeNew || l.condition == Condition.likeNew),
        )
        .toList();
    if (sort == 'Price: low to high') {
      results.sort((a, b) => a.price.compareTo(b.price));
    }
    if (sort == 'Price: high to low') {
      results.sort((a, b) => b.price.compareTo(a.price));
    }
    final c = context.colors;
    final filtered = query.isNotEmpty || under50 || likeNew || free;
    return ScreenScaffold(
      title: 'Search',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 16, color: c.ink),
              decoration: InputDecoration(
                hintText: 'Textbooks, a bike, headphones…',
                prefixIcon: Icon(
                  CupertinoIcons.search,
                  size: 19,
                  color: c.inkSoft,
                ),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 18,
                          color: c.inkFaint,
                        ),
                        onPressed: () {
                          _queryController.clear();
                          setState(() => query = '');
                        },
                      ),
                fillColor: c.surface2,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: BorderSide(color: c.ink, width: 1.5),
                ),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: gutter),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CategoryChip(
                  label: 'Under \$50',
                  selected: under50,
                  onTap: () => setState(() => under50 = !under50),
                ),
                CategoryChip(
                  label: 'Like New',
                  selected: likeNew,
                  onTap: () => setState(() => likeNew = !likeNew),
                ),
                CategoryChip(
                  label: 'Free',
                  selected: free,
                  onTap: () => setState(() => free = !free),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 16, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} results',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _chooseSort,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(CupertinoIcons.chevron_down, size: 14),
                      label: Text(
                        sort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(foregroundColor: c.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 48,
                horizontal: gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(CupertinoIcons.search, size: 40, color: c.inkFaint),
                  const SizedBox(height: 12),
                  Text(
                    'No matches. Try another search or remove a filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: c.inkSoft),
                  ),
                  if (filtered)
                    TextButton(
                      onPressed: _resetSearch,
                      child: const Text('Clear search and filters'),
                    ),
                ],
              ),
            ),
          ListingRows(listings: results),
        ],
      ),
    );
  }

  Future<void> _chooseSort() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Sort by'),
        actions: [
          for (final option in _sorts)
            CupertinoActionSheetAction(
              isDefaultAction: option == sort,
              onPressed: () => Navigator.pop(sheetContext, option),
              child: Text(option),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice != null && mounted) setState(() => sort = choice);
  }
}

const _sorts = ['Newest', 'Price: low to high', 'Price: high to low'];
