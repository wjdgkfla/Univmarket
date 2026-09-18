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

import 'widgets/pill_nav.dart';
import 'widgets/marketplace_refresh.dart';

/// Built fresh per [UnivMarketApp] instance rather than as a bare top-level
/// singleton — go_router still gets the single stable instance production
/// needs (built once in [UnivMarketApp]'s field initializer, never rebuilt),
/// but tests that pump multiple [UnivMarketApp]s no longer inherit
/// navigation state left over from a previous test's router.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/edit/:id',
      builder: (context, state) =>
          SellScreen(editingId: state.pathParameters['id']!),
    ),
    ShellRoute(
      builder: (context, state, child) => Stack(
        children: [
          child,
          PillNav(currentPath: state.uri.path),
        ],
      ),
      routes: [
        // Tabs swap instantly: a push-style transition would leave the
        // previous tab on screen underneath the incoming one.
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SearchScreen()),
        ),
        GoRoute(
          path: '/sell',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SellScreen()),
        ),
        GoRoute(
          path: '/saved',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SavedScreen()),
        ),
        GoRoute(
          path: '/inbox',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: InboxScreen()),
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

/// "GMUMarket", "GWUMarket", or the neutral brand before a school is known.
String marketName(String shortName) =>
    shortName.isEmpty ? 'UnivMarket' : '${shortName}Market';

class UnivMarketApp extends StatelessWidget {
  UnivMarketApp({super.key, Repository? repository})
    : repository = repository ?? Repository();

  final GoRouter _router = buildRouter();
  final Repository repository;

  @override
  Widget build(BuildContext context) {
    final school = schoolColors[repository.schoolShortName];
    final colors = school == null
        ? AppColors.light
        : AppColors.light.copyWith(
            accent: school.accent,
            accentDeep: school.accentDeep,
            accentWash: school.accentWash,
          );
    return ChangeNotifierProvider.value(
      value: repository,
      child: MaterialApp.router(
        title: marketName(repository.schoolShortName),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: colors.accent).copyWith(
            secondaryContainer: school?.second,
            onSecondaryContainer: school == null ? null : colors.ink,
          ),
          scaffoldBackgroundColor: colors.bg,
          extensions: [colors],
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.dark.bg,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.light,
        routerConfig: _router,
        builder: (context, child) {
          final bg = Theme.of(context).brightness == Brightness.dark
              ? AppColors.dark.bg
              : AppColors.light.bg;
          return ColoredBox(
            color: const Color(0xFFE8EAE8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                    child: ColoredBox(
                      color: bg,
                      child: MarketplaceRefresh(
                        repository: repository,
                        child: child ?? const SizedBox(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
