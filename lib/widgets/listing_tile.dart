import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../theme/tokens.dart';
import 'listing_image.dart';
import 'async_action.dart';

/// Grid card: square photo, bold price, two-line title, pickup spot.
class ListingTile extends StatefulWidget {
  final Listing listing;
  const ListingTile({super.key, required this.listing});

  @override
  State<ListingTile> createState() => _ListingTileState();
}

class _ListingTileState extends State<ListingTile> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final listing = widget.listing;
    final repo = context.watch<Repository>();
    final saved = repo.favorites.contains(listing.id);

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: () => context.push('/listing/${listing.id}'),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Hero(
                  tag: listingHeroTag(listing.id),
                  child: ListingImage(
                    listing: listing,
                    saved: saved,
                    onSave: () => runAction(
                      context,
                      () =>
                          context.read<Repository>().toggleFavorite(listing.id),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              priceText(context, listing.price, size: 17),
              const SizedBox(height: 2),
              Text(
                listing.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, height: 1.3, color: c.ink),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(CupertinoIcons.location, size: 13, color: c.inkSoft),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      listing.zone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.inkSoft),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
