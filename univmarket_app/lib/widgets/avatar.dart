import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  final VoidCallback? onTap;
  const Avatar({super.key, required this.initials, this.size = 36, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [colors.accent, colors.accentDeep, colors.pink],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: 'Open profile',
      child: GestureDetector(onTap: onTap, child: content),
    );
  }
}
