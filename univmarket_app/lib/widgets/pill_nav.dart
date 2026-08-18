import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/tokens.dart';

const _tabs = [
  (path: '/', icon: Icons.home_rounded, label: 'Home'),
  (path: '/search', icon: Icons.search_rounded, label: 'Search'),
  (path: '/sell', icon: Icons.add_rounded, label: 'Sell'),
  (path: '/saved', icon: Icons.favorite_rounded, label: 'Saved'),
  (path: '/inbox', icon: Icons.inbox_rounded, label: 'Inbox'),
];

class PillNav extends StatelessWidget {
  final String currentPath;
  const PillNav({super.key, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 12),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                side: BorderSide(color: c.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tab in _tabs)
                      _NavButton(tab: tab, active: tab.path == currentPath),
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

class _NavButton extends StatelessWidget {
  final ({String path, IconData icon, String label}) tab;
  final bool active;
  const _NavButton({required this.tab, required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: tab.label,
      selected: active,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.go(tab.path),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active
                ? LinearGradient(colors: [c.accent, c.accentDeep, c.pink])
                : null,
          ),
          child: Icon(
            tab.icon,
            size: 20,
            color: active ? Colors.white : c.inkFaint,
          ),
        ),
      ),
    );
  }
}
