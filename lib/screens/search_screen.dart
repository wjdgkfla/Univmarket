import 'dart:async';
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

  // A typed query searches the server (the loaded feed only holds its
  // newest page, so an older match would otherwise never turn up). Null
  // means "no server results yet" — falls back to filtering what's already
  // loaded, which is also the only path demo mode ever takes.
  List<Listing>? _serverResults;
  bool _searching = false;
  bool _searchFailed = false;
  Timer? _debounce;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _resetSearch() {
    _queryController.clear();
    _debounce?.cancel();
    setState(() {
      query = '';
      under50 = likeNew = free = false;
      _serverResults = null;
      _searchFailed = false;
    });
  }

  void _onQueryChanged(String value) {
    setState(() => query = value);
    _debounce?.cancel();
    if (context.read<Repository>().isDemo || value.trim().isEmpty) {
      setState(() {
        _serverResults = null;
        _searchFailed = false;
      });
      return;
    }
    final generation = ++_searchGeneration;
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(generation));
  }

  Future<void> _search(int generation) async {
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final results = await context.read<Repository>().searchListings(query);
      // A newer keystroke's search already landed; drop this stale one.
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _serverResults = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchFailed = true;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final base = _serverResults ?? repo.listListings();
    final results = base
        .where(
          (l) =>
              l.status == 'available' &&
              (_serverResults != null ||
                  ('${l.title} ${l.description} ${l.tag}')
                      .toLowerCase()
                      .contains(query.trim().toLowerCase())) &&
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
                          _onQueryChanged('');
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
              onChanged: _onQueryChanged,
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
                    _searching ? 'Searching…' : '${results.length} results',
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
          if (_searchFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Could not reach the server to search everything. Showing what\'s already loaded.',
                      style: TextStyle(fontSize: 13, color: c.inkSoft),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _search(_searchGeneration),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (results.isEmpty && !_searching)
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
