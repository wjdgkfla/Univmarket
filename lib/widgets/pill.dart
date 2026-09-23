import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum PillTone { good, warn, bad, neutral, accent, overlay }

/// Small status tag (Sample, Reserved, Sold, offer states).
class Pill extends StatelessWidget {
  final String label;
  final PillTone tone;
  const Pill({super.key, required this.label, this.tone = PillTone.neutral});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      PillTone.good => (c.goodWash, c.good),
      PillTone.warn => (c.warnWash, c.warn),
      PillTone.bad => (c.badWash, c.bad),
      PillTone.neutral => (c.surface2, c.inkSoft),
      PillTone.accent => (c.accentWash, c.accentDeep),
      PillTone.overlay => (const Color(0xB3111214), Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.2,
        ),
      ),
    );
  }
}
