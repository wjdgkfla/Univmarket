import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class ChipChoice extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const ChipChoice({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: active ? c.ink : c.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: active ? c.ink : c.line, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? c.bg : c.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
