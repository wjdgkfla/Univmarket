import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'category_art.dart';

class ListingImage extends StatelessWidget {
  const ListingImage({
    super.key,
    required this.listing,
    this.onSave,
    this.saved = false,
  });
  final Listing listing;
  final VoidCallback? onSave;
  final bool saved;
  @override
  Widget build(BuildContext context) {
    final source = listing.imageSource;
    Widget fallback() => CategoryArt(icon: listing.icon);
    Widget photo;
    if (source == null) {
      photo = fallback();
    } else if (source.startsWith('data:image/')) {
      try {
        photo = Image.memory(
          base64Decode(source.split(',').last),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback(),
        );
      } catch (_) {
        photo = fallback();
      }
    } else if (Uri.tryParse(source)?.scheme == 'https') {
      photo = Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      photo = Image.asset(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          if (listing.status != 'available')
            Positioned(
              left: 10,
              bottom: 10,
              child: Chip(label: Text(listing.status.toUpperCase())),
            ),
          if (onSave != null)
            Positioned(
              right: 6,
              top: 6,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(backgroundColor: Colors.white),
                tooltip: saved ? 'Remove from saved' : 'Save listing',
                onPressed: onSave,
                icon: Icon(
                  saved ? Icons.favorite : Icons.favorite_border,
                  color: saved ? context.colors.accent : Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
