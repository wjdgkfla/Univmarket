import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class _Blob {
  final double size, left, top;
  final Duration duration;
  final Color Function(AppColors) color;
  const _Blob(this.size, this.left, this.top, this.duration, this.color);
}

const _blobs = [
  _Blob(1.0, -0.3, -0.25, Duration(milliseconds: 13000), _accent),
  _Blob(0.85, 0.55, 0.05, Duration(milliseconds: 16000), _violet),
  _Blob(0.95, 0.05, 0.65, Duration(milliseconds: 14500), _pink),
];

Color _accent(AppColors c) => c.accent;
Color _violet(AppColors c) => c.violet;
Color _pink(AppColors c) => c.pink;

/// Slow drifting glow behind the whole app — flat, blurred, translucent
/// circles standing in for a true ambient gradient. Ponytail: no gaussian
/// mesh-gradient shader here, ImageFilter.blur on solid circles is the
/// cheap approximation; upgrade path is a custom shader if it ever needs
/// to look sharper up close.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final size = MediaQuery.of(context).size;
    final box = size.longestSide;

    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          children: [
            for (final blob in _blobs)
              _DriftingBlob(
                blob: blob,
                box: box,
                color: blob.color(colors),
                reduceMotion: reduceMotion,
              ),
          ],
        ),
      ),
    );
  }
}

class _DriftingBlob extends StatefulWidget {
  final _Blob blob;
  final double box;
  final Color color;
  final bool reduceMotion;
  const _DriftingBlob({
    required this.blob,
    required this.box,
    required this.color,
    required this.reduceMotion,
  });

  @override
  State<_DriftingBlob> createState() => _DriftingBlobState();
}

class _DriftingBlobState extends State<_DriftingBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.blob.duration,
    );
    if (!widget.reduceMotion) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.box * widget.blob.size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final dx = widget.box * 0.06 * t;
        final dy = -widget.box * 0.05 * t;
        final scale = 1 + 0.1 * t;
        return Positioned(
          left: widget.box * widget.blob.left + dx,
          top: widget.box * widget.blob.top + dy,
          child: Transform.scale(
            scale: scale,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
