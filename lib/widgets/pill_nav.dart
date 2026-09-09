import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _paths = ['/', '/search', '/sell', '/saved', '/inbox'];

class PillNav extends StatelessWidget {
  const PillNav({super.key, required this.currentPath});
  final String currentPath;
  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: NavigationBar(
      height: 72,
      selectedIndex: _paths.indexOf(currentPath).clamp(0, 4),
      onDestinationSelected: (i) => context.go(_paths[i]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          selectedIcon: Icon(Icons.add_circle),
          label: 'Sell',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          selectedIcon: Icon(Icons.favorite),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Inbox',
        ),
      ],
    ),
  );
}
