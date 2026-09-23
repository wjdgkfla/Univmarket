import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../theme/tokens.dart';
import 'fade_slide_in.dart';
import 'listing_image.dart';
import 'pill.dart';

/// List row: photo left, title, pickup spot and condition, price.
class ListingRow extends StatelessWidget {
  final Listing listing;
  const ListingRow({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = listing.status;
    return InkWell(
      onTap: () => context.push('/listing/${listing.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: ListingImage(listing: listing),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15.5, height: 1.3, color: c.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.zone} · ${listing.condition.label}${listing.trades ? ' · Trades ok' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (status != 'available')
                        Pill(
                          label: status,
                          tone: status == 'sold'
                              ? PillTone.neutral
                              : PillTone.good,
                        ),
                      priceText(context, listing.price),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rows separated by hairlines inset to the text column.
class ListingRows extends StatelessWidget {
  const ListingRows({super.key, required this.listings});
  final List<Listing> listings;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < listings.length; i++) ...[
        if (i > 0) const Divider(indent: gutter + 96 + 14, endIndent: gutter),
        // Keyed by id: rows that stay in a filtered list keep still.
        FadeSlideIn(
          key: ValueKey(listings[i].id),
          index: i,
          child: ListingRow(listing: listings[i]),
        ),
      ],
    ],
  );
}
