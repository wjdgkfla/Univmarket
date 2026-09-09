import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
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
    return ScreenScaffold(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find your next favorite',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search listings',
                hintText: 'Textbooks, a bike, headphones…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Under \$50'),
                  selected: under50,
                  onSelected: (v) => setState(() => under50 = v),
                ),
                FilterChip(
                  label: const Text('Like new'),
                  selected: likeNew,
                  onSelected: (v) => setState(() => likeNew = v),
                ),
                FilterChip(
                  label: const Text('Free'),
                  selected: free,
                  onSelected: (v) => setState(() => free = v),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} results',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DropdownButton<String>(
                  value: sort,
                  items: ['Newest', 'Price: low to high', 'Price: high to low']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => sort = v!),
                ),
              ],
            ),
            if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No matches. Try another search or remove a filter.',
                  ),
                ),
              ),
            for (final l in results)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListingRow(listing: l),
              ),
          ],
        ),
      ),
    );
  }
}
