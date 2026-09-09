import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:univmarket_app/data/demo_repository.dart';
import 'package:univmarket_app/data/models.dart';

class FailingStorage extends InMemorySharedPreferencesStore {
  FailingStorage() : super.empty();
  bool fail = true;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  test('failed storage rolls back a listing and later saves recover', () async {
    SharedPreferences.setMockInitialValues({});
    final store = FailingStorage();
    SharedPreferencesStorePlatform.instance = store;
    final repo = await DemoRepository.open();
    final count = repo.listListings().length;
    await expectLater(
      repo.createListing(
        title: 'Storage test monitor',
        price: 50,
        condition: Condition.good,
        category: 'Electronics',
        description: 'A working monitor with a cable.',
        acceptsTrades: false,
        pickupZoneName: repo.pickupZones.first,
      ),
      throwsStateError,
    );
    expect(repo.listListings().length, count);
    expect((await DemoRepository.open()).listListings().length, count);
    store.fail = false;
    await repo.toggleFavorite(repo.listListings().first.id);
    expect(
      (await DemoRepository.open()).favorites,
      contains(repo.listListings().first.id),
    );
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('campus feeds remain isolated and selection survives restart', () async {
    final repo = await DemoRepository.open();
    final original = repo.listListings().map((l) => l.id).toSet();
    await repo.selectUniversity('vt');
    expect(repo.listListings(), isNotEmpty);
    expect(repo.listListings().any((l) => original.contains(l.id)), isFalse);
    expect((await DemoRepository.open()).universityId, 'vt');
  });
  test('favorites and messages survive restart', () async {
    final repo = await DemoRepository.open();
    final id = repo.listListings().first.id;
    await repo.toggleFavorite(id);
    final conversation = await repo.conversationForListing(id);
    await repo.sendMessage(conversation, 'Can we meet tomorrow?');
    final reopened = await DemoRepository.open();
    expect(reopened.favorites, contains(id));
    expect(
      (reopened.getConversation(conversation)!.messages.last as TextMessage)
          .body,
      'Can we meet tomorrow?',
    );
  });
  test(
    'listing creation validates input and stores what the user entered',
    () async {
      final repo = await DemoRepository.open();
      Future<void> post(String title, int price) => repo.createListing(
        title: title,
        price: price,
        condition: Condition.good,
        category: 'Electronics',
        description: 'A working monitor with its power cable.',
        acceptsTrades: false,
        pickupZoneName: repo.pickupZones.first,
      );
      await expectLater(post('', 20), throwsArgumentError);
      await expectLater(post('Monitor', -1), throwsArgumentError);
      await post('My monitor', 75);
      final listing = (await DemoRepository.open()).listListings().first;
      expect(listing.title, 'My monitor');
      expect(listing.price, 75);
      expect(listing.sellerId, repo.me.id);
    },
  );
  test('only an incoming pending offer can be accepted once', () async {
    final repo = await DemoRepository.open();
    final thread = repo.listConversations().first;
    final incoming = thread.messages.whereType<OfferMessage>().first;
    await repo.acceptOffer(thread.id, incoming.id);
    expect(repo.getListing(thread.listingId)!.status, 'reserved');
    await expectLater(
      repo.acceptOffer(thread.id, incoming.id),
      throwsStateError,
    );
    final restored = await DemoRepository.open();
    expect(restored.getListing(thread.listingId)!.status, 'reserved');
  });
  test('seller ownership is enforced for listing status changes', () async {
    final repo = await DemoRepository.open();
    final other = repo.listListings().firstWhere(
      (l) => l.sellerId != repo.me.id,
    );
    await expectLater(repo.markSold(other.id), throwsStateError);
  });
}
