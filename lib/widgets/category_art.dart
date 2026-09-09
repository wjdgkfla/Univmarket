import 'package:flutter/material.dart';
import '../theme/tokens.dart';

const Map<String, IconData> _categoryIcons = {
  'book': Icons.menu_book_rounded,
  'headphones': Icons.headphones_rounded,
  'chair': Icons.chair_rounded,
  'bike': Icons.pedal_bike_rounded,
  'lamp': Icons.light_rounded,
  'shirt': Icons.checkroom_rounded,
  'bag': Icons.shopping_bag_rounded,
  'board': Icons.dashboard_rounded,
};

class CategoryArt extends StatelessWidget {
  final String icon;
  final BorderRadius? borderRadius;
  final double glyphScale;
  final VoidCallback? onSave;
  final bool saved;

  const CategoryArt({
    super.key,
    required this.icon,
    this.borderRadius,
    this.glyphScale = 1,
    this.onSave,
    this.saved = false,
  });

  @override
  Widget build(BuildContext context) {
    final mesh = categoryMesh[icon]!;
    final colors = context.colors;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.7, -0.75),
                radius: 1.3,
                colors: mesh,
                stops: const [0, 0.48, 1],
              ),
            ),
          ),
          Center(
            child: Transform.scale(
              scale: glyphScale,
              child: Icon(_categoryIcons[icon], size: 40, color: mesh.last),
            ),
          ),
          if (onSave != null)
            Positioned(
              top: 8,
              right: 8,
              child: Semantics(
                button: true,
                label: saved ? 'Remove from saved' : 'Save listing',
                child: GestureDetector(
                  onTap: onSave,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: saved
                          ? colors.accent
                          : Colors.black.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
