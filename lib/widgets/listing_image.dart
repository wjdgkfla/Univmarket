import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'pill.dart';

/// Hero tag shared by the Home grid photo and the listing detail photo.
String listingHeroTag(String id) => 'listing-photo-$id';

class ListingImage extends StatelessWidget {
  const ListingImage({
    super.key,
    required this.listing,
    this.onSave,
    this.saved = false,
    this.radius = AppRadius.photo,
    this.showStatus = true,
  });
  final Listing listing;
  final VoidCallback? onSave;
  final bool saved;
  final double radius;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final source =
        listing.imageSource ??
        (listing.isSample
            ? switch (listing.tag) {
                'Textbooks' => 'assets/images/books.jpg',
                'Electronics' => 'assets/images/headphones.jpg',
                'Dorm' => 'assets/images/lamp.jpg',
                'Bags' => 'assets/images/bag.jpg',
                _ => null,
              }
            : null);
    Widget fallback() => ColoredBox(
      color: c.surface2,
      child: Center(
        child: Icon(CupertinoIcons.photo, size: 28, color: c.inkFaint),
      ),
    );
    Widget photo;
    if (source == null) {
      photo = fallback();
    } else if (source.startsWith('data:image/')) {
      try {
        photo = Image.memory(
          base64Decode(source.split(',').last),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback(),
        );
      } catch (_) {
        photo = fallback();
      }
    } else if (Uri.tryParse(source)?.scheme == 'https') {
      photo = Image.network(
        source,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, sync) =>
            sync || frame != null ? child : ColoredBox(color: c.surface2),
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      photo = Image.asset(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    final sold = listing.status == 'sold';
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: c.surface2, child: photo),
          // Hairline keeps white product shots from bleeding into the page.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: const Color(0x0F000000), width: 0.5),
            ),
          ),
          if (showStatus && sold)
            ColoredBox(
              color: const Color(0x73111214),
              child: Center(
                child: Text(
                  'Sold',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: radius > 4 ? 15 : 13,
                  ),
                ),
              ),
            ),
          if (listing.isSample)
            const Positioned(
              left: 8,
              top: 8,
              child: Pill(label: 'Sample', tone: PillTone.overlay),
            ),
          if (showStatus && listing.status == 'reserved')
            const Positioned(
              left: 8,
              bottom: 8,
              child: Pill(label: 'reserved', tone: PillTone.overlay),
            ),
          if (onSave != null)
            Positioned(
              right: 2,
              top: 2,
              child: _SaveButton(saved: saved, onPressed: onSave!),
            ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onPressed});
  final bool saved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      toggled: saved,
      child: Tooltip(
        message: saved ? 'Remove from saved' : 'Save listing',
        child: InkResponse(
          onTap: onPressed,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween(begin: 0.6, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: child,
                  ),
                  child: Icon(
                    saved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    key: ValueKey(saved),
                    size: 17,
                    color: saved ? c.accent : const Color(0xFF17191C),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
