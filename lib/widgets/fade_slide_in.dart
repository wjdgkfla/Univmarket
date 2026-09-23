import 'dart:math';

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Fades and lifts [child] in once, when it first appears. [index] staggers
/// siblings (capped so long lists never wait). Key it by item identity so
/// only new items animate on rebuilds.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.animate = true,
  });
  final Widget child;
  final int index;

  /// False shows [child] at rest, e.g. messages that were already on screen.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final delay = AppMotion.stagger * min(index, 6);
    final total = AppMotion.of(context, delay + AppMotion.base);
    final start = total == Duration.zero
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      // Only the first build's begin is used, so later rebuilds never restart.
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: AppMotion.curve),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
