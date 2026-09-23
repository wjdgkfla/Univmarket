import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  final VoidCallback? onTap;
  const Avatar({super.key, required this.initials, this.size = 40, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.accentWash, shape: BoxShape.circle),
      child: Text(
        initials,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: c.accentDeep,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
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
