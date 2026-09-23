import 'package:flutter/material.dart';

/// UnivMarket mark: a shopping bag with a U cut from its body.
///
/// Drawn on a 120-unit grid; the mark itself spans x 28-92, y 23-96. This one
/// painter renders the in-app logo and, via tool/export_icons_test.dart, every
/// app icon, so the two cannot drift apart.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    required this.color,
    required this.knockout,
    this.tile,
    this.markScale = 1,
  });

  /// Bag and handle color.
  final Color color;

  /// Color of the U cut into the bag (the surface behind the mark).
  final Color knockout;

  /// When set, fills the whole canvas first (app icon background).
  final Color? tile;

  /// Scales the mark around the canvas center (icons need safe-area padding).
  final double markScale;

  /// Bounds of the mark on the 120 grid, for tight in-app cropping.
  static const bounds = Rect.fromLTRB(28, 23, 92, 96);

  @override
  void paint(Canvas canvas, Size size) {
    if (tile != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = tile!);
    }
    canvas.save();
    if (tile != null) {
      // Icon: center the 120 grid, scaled to fit.
      final s = size.shortestSide / 120 * markScale;
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(s);
      canvas.translate(-60, -59.5);
    } else {
      // Inline mark: crop to the mark's own bounds.
      final s = size.height / bounds.height;
      canvas.translate(
        (size.width - bounds.width * s) / 2 - bounds.left * s,
        -bounds.top * s,
      );
      canvas.scale(s);
    }

    // A transparent knockout must erase the body, not paint over it.
    final erase = knockout.a == 0;
    if (erase) canvas.saveLayer(bounds.inflate(8), Paint());
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Handle.
    canvas.drawPath(
      Path()
        ..moveTo(41, 43)
        ..lineTo(41, 38)
        ..arcToPoint(
          const Offset(79, 38),
          radius: const Radius.elliptical(19, 12),
        )
        ..lineTo(79, 43),
      stroke
        ..color = color
        ..strokeWidth = 6,
    );

    // Bag body.
    canvas.drawRRect(
      RRect.fromLTRBR(28, 42, 92, 96, const Radius.circular(10)),
      Paint()..color = color,
    );

    // The U.
    canvas.drawPath(
      Path()
        ..moveTo(48, 54)
        ..lineTo(48, 68)
        ..arcToPoint(
          const Offset(72, 68),
          radius: const Radius.circular(12),
          clockwise: false,
        )
        ..lineTo(72, 54),
      stroke
        ..color = erase ? const Color(0xFF000000) : knockout
        ..blendMode = erase ? BlendMode.clear : BlendMode.srcOver
        ..strokeWidth = 9,
    );
    if (erase) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.color != color ||
      old.knockout != knockout ||
      old.tile != tile ||
      old.markScale != markScale;
}

/// The mark at a given height, e.g. beside the market name.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    required this.size,
    required this.color,
    this.knockout = Colors.white,
  });
  final double size;
  final Color color;
  final Color knockout;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(
        size * BrandMarkPainter.bounds.width / BrandMarkPainter.bounds.height,
        size,
      ),
      painter: BrandMarkPainter(color: color, knockout: knockout),
    ),
  );
}

/// Rounded app-icon tile, for sign-in and other pre-school screens.
class AppIconTile extends StatelessWidget {
  const AppIconTile({super.key, this.size = 64});
  final double size;

  static const ink = Color(0xFF17191C);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.225),
      child: CustomPaint(
        size: Size.square(size),
        painter: const BrandMarkPainter(
          color: Colors.white,
          knockout: ink,
          tile: ink,
        ),
      ),
    ),
  );
}
