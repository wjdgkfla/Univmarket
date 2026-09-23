import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'data/repository.dart';
import 'screens/admin_reports_screen.dart';
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
import 'widgets/inbox_live_sync.dart';
import 'widgets/marketplace_refresh.dart';
import 'widgets/report_alerts.dart';

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
    StatefulShellRoute(
      builder: (context, state, shell) => Stack(
        children: [
          shell,
          AppTabBar(currentPath: state.uri.path, onSelect: shell.goBranch),
        ],
      ),
      navigatorContainerBuilder: (context, shell, children) =>
          _FadingTabs(index: shell.currentIndex, children: children),
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
    GoRoute(
      path: '/admin/reports',
      builder: (context, state) => const AdminReportsScreen(),
    ),
  ],
);

/// Keeps every tab mounted like an IndexedStack, but fades the selected tab
/// in. The previous tab goes offstage at once, so it never shows underneath.
class _FadingTabs extends StatefulWidget {
  const _FadingTabs({required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<_FadingTabs> createState() => _FadingTabsState();
}

class _FadingTabsState extends State<_FadingTabs>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, value: 1);
  late final _opacity = CurvedAnimation(parent: _fade, curve: AppMotion.curve);

  @override
  void didUpdateWidget(_FadingTabs old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _fade.duration = AppMotion.of(context, AppMotion.fast);
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          // Same wrappers for every tab, so switching never remounts one.
          Offstage(
            offstage: i != widget.index,
            child: TickerMode(
              enabled: i == widget.index,
              child: FadeTransition(
                opacity: i == widget.index
                    ? _opacity
                    : kAlwaysCompleteAnimation,
                child: widget.children[i],
              ),
            ),
          ),
      ],
    );
  }
}

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
                        child: InboxLiveSync(
                          repository: repository,
                          child: ReportAlerts(
                            repository: repository,
                            onReview: () => _router.push('/admin/reports'),
                            child: child ?? const SizedBox(),
                          ),
                        ),
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
