import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum PillTone { good, warn, bad, neutral, accent }

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
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
