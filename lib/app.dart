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

import 'widgets/tab_bar.dart';
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
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Stack(
        children: [
          shell,
          AppTabBar(currentPath: state.uri.path, onSelect: shell.goBranch),
        ],
      ),
      branches: [
        // Keep each tab's form, search and scroll state while switching tabs.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SearchScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sell',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SellScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saved',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SavedScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inbox',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: InboxScreen()),
            ),
          ],
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
        theme: buildTheme(colors),
        themeMode: ThemeMode.light,
        routerConfig: _router,
        builder: (context, child) {
          final bg = colors.bg;
          return ColoredBox(
            color: const Color(0xFFE9EBEE),
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
