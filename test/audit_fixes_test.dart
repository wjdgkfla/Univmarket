import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'demo_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/listing_detail_screen.dart';
import 'package:univmarket_app/screens/profile_screen.dart';
import 'package:univmarket_app/theme/tokens.dart';
import 'package:univmarket_app/widgets/async_action.dart';

void main() {
  const generic = 'Something went wrong. Check your connection and try again.';

  test('server rejections written for students are shown verbatim', () {
    expect(
      friendlyError(
        const PostgrestException(message: 'Offer expired', code: '22023'),
      ),
      'Offer expired',
    );
    expect(
      friendlyError(
        const PostgrestException(message: 'Listing unavailable', code: '42501'),
      ),
      'Listing unavailable',
    );
  });

  test('internal database and network errors stay generic', () {
    for (final message in [
      'new row violates row-level security policy for table "listings"',
      'permission denied for table listings',
    ]) {
      expect(
        friendlyError(PostgrestException(message: message, code: '42501')),
        generic,
      );
    }
    expect(friendlyError(Exception('socket closed')), generic);
  });

  test('a failed photo upload says so', () {
    expect(
      friendlyError(StorageException('Bucket not found')),
      contains('photo could not be uploaded'),
    );
  });

  test('a pending offer past its deadline reads as expired', () {
    OfferMessage offer(OfferStatus status, DateTime? expiresAt) => OfferMessage(
      'o',
      MessageFrom.them,
      10,
      'l',
      status,
      expiresAt: expiresAt,
    );
    final past = DateTime.now().subtract(const Duration(minutes: 1));
    final future = DateTime.now().add(const Duration(hours: 1));
    expect(offer(OfferStatus.pending, past).isExpired, isTrue);
    expect(offer(OfferStatus.pending, future).isExpired, isFalse);
    expect(offer(OfferStatus.pending, null).isExpired, isFalse);
    expect(offer(OfferStatus.accepted, past).isExpired, isFalse);
    expect(offer(OfferStatus.pending, past).copyWith().isExpired, isTrue);
  });

  testWidgets('pulling the Home feed down starts a refresh', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.fling(
      find.text('Fresh on campus'),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final sold in [true, false]) {
    testWidgets(
      'seller can ${sold ? 'mark a reserved listing sold' : 'cancel a reservation'}',
      (tester) async {
        final repo = _ReservedRepo();
        await tester.pumpWidget(
          ChangeNotifierProvider<Repository>.value(
            value: repo,
            child: MaterialApp(
              theme: buildTheme(AppColors.light),
              home: const ListingDetailScreen(id: 'mine'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Editing is not offered while the item is reserved.
        expect(find.text('Edit listing'), findsNothing);
        final label = sold ? 'Mark as sold' : 'Cancel reservation';
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(repo.finished, [('mine', sold)]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('blocking a seller hides them everywhere until unblocked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculus textbook, 9th edition'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block Alex Morgan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block').last);
    await tester.pumpAndSettle();

    // Back on Home with the seller's listings and chats gone.
    expect(find.text('Fresh on campus'), findsOneWidget);
    expect(find.text('Calculus textbook, 9th edition'), findsNothing);
    expect(find.text('Alex Morgan is blocked.'), findsOneWidget);
    expect(repo.listConversations(), isEmpty);

    // Profile lists them; unblocking brings everything back.
    await tester.tap(find.byTooltip('Your profile'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked students'), findsOneWidget);
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked students'), findsNothing);
    expect(repo.listListings(), isNotEmpty);
    expect(repo.listConversations(), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reporting a listing asks for a reason and confirms', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await DemoRepository.open();
    await tester.pumpWidget(UnivMarketApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculus textbook, 9th edition'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report listing'));
    await tester.pumpAndSettle();
    expect(find.text('Why are you reporting this?'), findsOneWidget);
    await tester.tap(find.text('Scam or fraud'));
    await tester.pumpAndSettle();
    expect(find.textContaining('We review every report'), findsOneWidget);
    // Reporting does not block or navigate away.
    expect(repo.blocked, isEmpty);
    expect(find.text('Calculus textbook, 9th edition'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account deletion asks first, then deletes once', (tester) async {
    final repo = _DeletingRepo();
    await tester.pumpWidget(
      ChangeNotifierProvider<Repository>.value(
        value: repo,
        child: MaterialApp(
          theme: buildTheme(AppColors.light),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deletions, 0);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account').last);
    await tester.pumpAndSettle();
    expect(repo.deletions, 1);
    expect(tester.takeException(), isNull);
  });
}

/// Offline repository holding one reserved listing owned by "me".
class _ReservedRepo extends Repository {
  _ReservedRepo() : super.offline();
  final finished = <(String, bool)>[];
  static const _listing = Listing(
    id: 'mine',
    icon: 'lamp',
    title: 'Desk lamp',
    price: 15,
    condition: Condition.good,
    zone: 'Library',
    tag: 'Dorm',
    trades: false,
    description: 'A working desk lamp.',
    sellerId: '',
    status: 'reserved',
  );
  @override
  Listing? getListing(String id) => id == 'mine' ? _listing : null;
  @override
  Profile? getSeller(String id) => null;
  @override
  Future<void> finishReservation(
    String listingId, {
    required bool sold,
  }) async => finished.add((listingId, sold));
}

class _DeletingRepo extends Repository {
  _DeletingRepo() : super.offline();
  int deletions = 0;
  @override
  Future<void> deleteAccount() async => deletions++;
}
