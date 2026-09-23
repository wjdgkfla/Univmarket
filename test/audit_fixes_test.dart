import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/listing_detail_screen.dart';
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
