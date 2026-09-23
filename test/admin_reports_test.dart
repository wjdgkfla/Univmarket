import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/admin_reports_screen.dart';
import 'package:univmarket_app/screens/profile_screen.dart';
import 'package:univmarket_app/theme/tokens.dart';

/// Offline repository with a moderator flag and an in-memory report queue.
class _AdminRepo extends Repository {
  _AdminRepo({this.admin = true}) : super.offline();
  final bool admin;
  final resolved = <(String, String)>[];
  final queue = [
    AdminReport(
      id: 'r1',
      reason: 'scam',
      notes: 'Asked for a deposit',
      createdAt: DateTime(2026, 9, 23),
      reporterName: 'Jordan Lee',
      reportedUserId: 'u1',
      reportedUserName: 'Casey Park',
      reportedUserState: 'active',
      openReportsOnUser: 2,
      listingId: 'l1',
      listingTitle: 'Cheap laptop',
    ),
    const AdminReport(
      id: 'r2',
      reason: 'harassment',
      reporterName: 'Jordan Lee',
      reportedUserId: 'u1',
      reportedUserName: 'Casey Park',
      reportedUserState: 'active',
      openReportsOnUser: 2,
    ),
  ];
  @override
  bool get isAdmin => admin;
  @override
  Future<List<AdminReport>> openReports() async => [...queue];
  @override
  Future<void> resolveReport(String reportId, String action) async {
    resolved.add((reportId, action));
    queue.removeWhere((r) => r.id == reportId);
  }
}

Widget _host(Repository repo, Widget home) => ChangeNotifierProvider.value(
  value: repo,
  child: MaterialApp(theme: buildTheme(AppColors.light), home: home),
);

void main() {
  testWidgets('only admins see the report queue entry', (tester) async {
    await tester.pumpWidget(
      _host(_AdminRepo(admin: false), const ProfileScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review reports'), findsNothing);

    await tester.pumpWidget(_host(_AdminRepo(), const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Review reports'), findsOneWidget);
  });

  testWidgets('admin hides a reported listing from the queue', (tester) async {
    final repo = _AdminRepo();
    await tester.pumpWidget(_host(repo, const AdminReportsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Listing: Cheap laptop'), findsOneWidget);
    expect(find.textContaining('2 open reports'), findsNWidgets(2));
    expect(find.text('"Asked for a deposit"'), findsOneWidget);

    await tester.tap(find.text('Listing: Cheap laptop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide listing'));
    await tester.pumpAndSettle();
    expect(repo.resolved, [('r1', 'hide_listing')]);
    expect(find.text('Listing hidden.'), findsOneWidget);
    expect(find.text('Listing: Cheap laptop'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suspending asks for confirmation first', (tester) async {
    final repo = _AdminRepo();
    await tester.pumpWidget(_host(repo, const AdminReportsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About the student'));
    await tester.pumpAndSettle();
    // A report without a listing offers no Hide action.
    expect(find.text('Hide listing'), findsNothing);
    await tester.tap(find.text('Suspend Casey Park'));
    await tester.pumpAndSettle();
    expect(find.text('Suspend Casey Park?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.resolved, isEmpty);

    await tester.tap(find.text('About the student'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspend Casey Park'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    expect(repo.resolved, [('r2', 'suspend_user')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty queue says so', (tester) async {
    final repo = _AdminRepo()..queue.clear();
    await tester.pumpWidget(_host(repo, const AdminReportsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No open reports'), findsOneWidget);
  });
}
