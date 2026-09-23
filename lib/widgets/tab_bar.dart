import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../theme/tokens.dart';

const _paths = ['/', '/search', '/sell', '/saved', '/inbox'];

const _items = [
  (
    label: 'Home',
    icon: CupertinoIcons.house,
    active: CupertinoIcons.house_fill,
  ),
  (label: 'Search', icon: CupertinoIcons.search, active: CupertinoIcons.search),
  (
    label: 'Sell',
    icon: CupertinoIcons.plus_circle,
    active: CupertinoIcons.plus_circle_fill,
  ),
  (
    label: 'Saved',
    icon: CupertinoIcons.heart,
    active: CupertinoIcons.heart_fill,
  ),
  (
    label: 'Inbox',
    icon: CupertinoIcons.chat_bubble_2,
    active: CupertinoIcons.chat_bubble_2_fill,
  ),
];

/// iOS-style tab bar on a translucent material, overlaying tab screens.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.currentPath, this.onSelect});
  final String currentPath;
  final ValueChanged<int>? onSelect;

  static const double barHeight = 52;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = _paths.indexOf(currentPath).clamp(0, 4);
    final unread = context.watch<Repository>().listConversations().any(
      (conversation) => conversation.unread,
    );
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(bottom: bottom),
            decoration: BoxDecoration(
              color: c.bg.withValues(alpha: 0.92),
              border: Border(top: BorderSide(color: c.line, width: 0.5)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                height: barHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: _TabItem(
                          label: _items[i].label,
                          icon: i == selected
                              ? _items[i].active
                              : _items[i].icon,
                          selected: i == selected,
                          badge: i == 4 && unread,
                          onTap: () => onSelect != null
                              ? onSelect!(i)
                              : context.go(_paths[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.badge,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected, badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.accent : c.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: badge ? '$label, unread messages' : null,
      excludeSemantics: badge,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        highlightShape: BoxShape.circle,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 24, color: color),
                  if (badge)
                    Positioned(
                      right: -3,
                      top: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: c.bad,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
