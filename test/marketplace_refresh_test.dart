import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/widgets/marketplace_refresh.dart';

class RefreshRepository extends Repository {
  RefreshRepository() : super.offline();
  int calls = 0;
  bool fail = false;
  @override
  Future<void> refreshMarketplace() async {
    calls++;
    if (fail) throw StateError('offline');
  }
}

void main() {
  testWidgets('refreshes before expiry and retries a failed refresh', (
    tester,
  ) async {
    final repo = RefreshRepository()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceRefresh(
          repository: repo,
          interval: const Duration(minutes: 45),
          child: const Text('Catalog'),
        ),
      ),
    );
    await tester.pump(const Duration(minutes: 45));
    await tester.pump();
    expect(repo.calls, 1);
    expect(find.textContaining('Could not refresh'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(repo.calls, 2);
    expect(find.textContaining('Could not refresh'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
  testWidgets('pauses background refresh and reloads on resume', (
    tester,
  ) async {
    final repo = RefreshRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceRefresh(repository: repo, child: const SizedBox()),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(hours: 2));
    expect(repo.calls, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.calls, 1);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
}
