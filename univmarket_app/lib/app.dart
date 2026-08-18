import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'data/repository.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/listing_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'screens/sell_screen.dart';
import 'theme/tokens.dart';
import 'widgets/ambient_glow.dart';
import 'widgets/pill_nav.dart';

/// Built fresh per [UnivMarketApp] instance rather than as a bare top-level
/// singleton — go_router still gets the single stable instance production
/// needs (built once in [UnivMarketApp]'s field initializer, never rebuilt),
/// but tests that pump multiple [UnivMarketApp]s no longer inherit
/// navigation state left over from a previous test's router.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => Stack(
        children: [
          child,
          PillNav(currentPath: state.uri.path),
        ],
      ),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(path: '/sell', builder: (context, state) => const SellScreen()),
        GoRoute(
          path: '/saved',
          builder: (context, state) => const SavedScreen(),
        ),
        GoRoute(
          path: '/inbox',
          builder: (context, state) => const InboxScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/listing/:id',
      builder: (context, state) =>
          ListingDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) => ChatScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);

class UnivMarketApp extends StatelessWidget {
  UnivMarketApp({super.key, Repository? repository})
    : repository = repository ?? Repository();

  final GoRouter _router = buildRouter();
  final Repository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: repository,
      child: MaterialApp.router(
        title: 'UnivMarket',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.light.bg,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.dark.bg,
          useMaterial3: true,
        ),
        routerConfig: _router,
        builder: (context, child) {
          final bg = Theme.of(context).brightness == Brightness.dark
              ? AppColors.dark.bg
              : AppColors.light.bg;
          return DecoratedBox(
            decoration: BoxDecoration(color: bg),
            child: Stack(
              children: [
                const Positioned.fill(child: AmbientGlow()),
                ?child,
              ],
            ),
          );
        },
      ),
    );
  }
}
