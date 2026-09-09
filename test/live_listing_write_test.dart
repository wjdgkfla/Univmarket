import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/data/models.dart';

Future<({Repository repo, List<http.Request> requests})> fixture({
  bool rejectUpdates = false,
  bool rejectUploads = false,
  bool withConversation = false,
  bool rejectOffers = false,
  String sellerId = 'student',
}) async {
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'https://test.invalid',
    'public-test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
      if (rejectUploads && request.url.path.startsWith('/storage/v1/object/')) {
        return http.Response(
          jsonEncode({
            'statusCode': '403',
            'error': 'Unauthorized',
            'message': 'Upload denied',
          }),
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      if (rejectUpdates && request.method == 'PATCH') {
        return http.Response(
          jsonEncode({
            'code': 'PGRST116',
            'message': 'Cannot coerce the result to a single JSON object',
            'details': 'The result contains 0 rows',
            'hint': null,
          }),
          406,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      Object result = [];
      final path = request.url.path;
      if (path.endsWith('/rpc/send_offer')) {
        if (rejectOffers) {
          return http.Response(
            jsonEncode({'code': 'P0001', 'message': 'messaging unavailable'}),
            400,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        result = 'offer-confirmed';
      } else if (path.endsWith('/conversations') && withConversation) {
        result = [
          {
            'id': 'thread',
            'listing_id': 'listing-b',
            'buyer_id': 'student',
            'seller_id': sellerId,
          },
        ];
      } else if (path.startsWith('/storage/v1/object/sign/')) {
        result = {
          'signedURL': '/object/sign/listing-images/photo.jpg?token=test',
        };
      } else if (path.startsWith('/storage/v1/object/')) {
        result = {'Key': path};
      } else if (path == '/auth/v1/token') {
        result = {
          'access_token': [
            base64Url.encode(
              utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
            ),
            base64Url.encode(
              utf8.encode(
                jsonEncode({
                  'sub': 'student',
                  'role': 'authenticated',
                  'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                }),
              ),
            ),
            'signature',
          ].join('.'),
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 'student',
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-01-01T00:00:00Z',
            'email_confirmed_at': '2026-01-01T00:00:00Z',
            'is_anonymous': false,
          },
        };
      } else if (path.endsWith('/rpc/ensure_profile')) {
        result = {
          'id': 'student',
          'display_name': 'Student',
          'university_id': 'school-b',
          'home_campus_id': 'campus-b',
        };
      } else if (path.endsWith('/universities')) {
        result = {'id': 'school-b', 'name': 'Second University'};
      } else if (path.endsWith('/campuses')) {
        result = {'id': 'campus-b', 'university_id': 'school-b'};
      } else if (path.endsWith('/pickup_zones')) {
        result = [
          {'id': 'zone-b', 'name': 'Campus B library'},
        ];
      } else if (path.endsWith('/listings')) {
        result = [
          {
            'id': 'listing-b',
            'university_id': 'school-b',
            'seller_id': sellerId,
            'title': 'Course book',
            'price': 12,
            'category': 'Textbooks',
            'condition': 'good',
            'pickup_zone_id': 'zone-b',
            'status': 'available',
            'cover_image_url': 'https://test.invalid/book.jpg',
          },
        ];
      }
      if (path.endsWith('/listings') && request.method == 'PATCH') {
        result = rejectUpdates
            ? []
            : {
                ...(result as List).single as Map<String, dynamic>,
                ...jsonDecode(request.body) as Map<String, dynamic>,
              };
      }
      if (path.endsWith('/listings') && request.method == 'POST') {
        result = {
          'id': 'new-listing',
          'status': 'available',
          ...jsonDecode(request.body) as Map<String, dynamic>,
        };
      }
      return http.Response(
        jsonEncode(result),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  addTearDown(client.dispose);
  await client.auth.signInWithPassword(
    email: 'student@test.invalid',
    password: 'test-password',
  );
  final repo = Repository(client: client);
  addTearDown(repo.dispose);
  await repo.initialized;
  expect(repo.bootstrapError, isNull);
  requests.clear();
  return (repo: repo, requests: requests);
}

Future<void> save(
  Repository repo, {
  String? id,
  String zone = 'Campus B library',
  int price = 20,
  String title = ' Updated book ',
  String? photo,
}) => repo.createListing(
  title: title,
  price: price,
  condition: Condition.good,
  category: 'Textbooks',
  description: ' In very good condition ',
  acceptsTrades: false,
  pickupZoneName: zone,
  editingId: id,
  imageSource: photo,
);
void main() {
  test(
    'mark sold rejects another owner and rejected updates preserve availability',
    () async {
      final outsider = await fixture(sellerId: 'other');
      await expectLater(outsider.repo.markSold('listing-b'), throwsStateError);
      expect(outsider.requests, isEmpty);
      final denied = await fixture(rejectUpdates: true);
      await expectLater(
        denied.repo.markSold('listing-b'),
        throwsA(isA<PostgrestException>()),
      );
      expect(denied.repo.getListing('listing-b')!.status, 'available');
    },
  );
  test(
    'live buyer sends cash offer and caches only the confirmed offer ID',
    () async {
      final f = await fixture(withConversation: true, sellerId: 'seller');
      await f.repo.sendOffer('thread', 25);
      expect(f.requests.single.url.path, '/rest/v1/rpc/send_offer');
      expect(jsonDecode(f.requests.single.body), {
        'p_conversation_id': 'thread',
        'p_kind': 'cash',
        'p_cash_amount': 25,
        'p_offered_listing_ids': [],
      });
      final message =
          f.repo.getConversation('thread')!.messages.single as OfferMessage;
      expect(message.id, 'offer-confirmed');
      expect(message.amount, 25);
      expect(message.status, OfferStatus.pending);
    },
  );
  test('rejected offer does not add a local success message', () async {
    final f = await fixture(
      withConversation: true,
      sellerId: 'seller',
      rejectOffers: true,
    );
    await expectLater(
      f.repo.sendOffer('thread', 25),
      throwsA(isA<PostgrestException>()),
    );
    expect(f.repo.getConversation('thread')!.messages, isEmpty);
  });
  test('invalid amounts and own listings cannot receive offers', () async {
    final f = await fixture(withConversation: true);
    await expectLater(f.repo.sendOffer('thread', 0), throwsArgumentError);
    await expectLater(f.repo.sendOffer('thread', 25), throwsStateError);
    expect(f.requests, isEmpty);
  });
  test(
    'mark sold updates only an owned available listing and confirms result',
    () async {
      final f = await fixture();
      await f.repo.markSold('listing-b');
      expect(jsonDecode(f.requests.single.body), {'status': 'sold'});
      expect(f.requests.single.url.queryParameters['seller_id'], 'eq.student');
      expect(f.requests.single.url.queryParameters['status'], 'eq.available');
      expect(f.repo.getListing('listing-b')!.status, 'sold');
    },
  );
  test(
    'upload rejection stops the listing write and preserves cached listings',
    () async {
      final f = await fixture(rejectUploads: true);
      await expectLater(
        save(f.repo, photo: 'data:image/png;base64,iVBORw0KGgoA'),
        throwsA(isA<StorageException>()),
      );
      expect(f.requests.length, 1);
      expect(f.repo.getListing('new-listing'), isNull);
      expect(f.repo.getListing('listing-b')?.title, 'Course book');
    },
  );
  test(
    'uploads a new photo before saving its private path on the listing',
    () async {
      final f = await fixture();
      await save(f.repo, photo: 'data:image/png;base64,iVBORw0KGgoA');
      final upload = f.requests.first;
      expect(
        upload.url.path,
        matches(
          r'^/storage/v1/object/listing-images/school-b/student/[a-f0-9]{32}\.png$',
        ),
      );
      final write = f.requests.singleWhere(
        (r) => r.url.path.endsWith('/listings'),
      );
      final body = jsonDecode(write.body);
      expect(body['cover_image_url'], startsWith('school-b/student/'));
      expect(body['image_urls'], [body['cover_image_url']]);
      expect(
        f.repo.getListing('new-listing')?.imageSource,
        startsWith('https://test.invalid/storage/v1/object/sign/'),
      );
    },
  );
  test('rejects invalid pickup zone and price before writing', () async {
    final f = await fixture();
    await expectLater(save(f.repo, zone: 'Other campus'), throwsArgumentError);
    await expectLater(save(f.repo, price: -1), throwsArgumentError);
    expect(f.requests, isEmpty);
  });
  test(
    'creates trimmed listing and caches the confirmed server result',
    () async {
      final f = await fixture();
      await save(f.repo);
      final write = f.requests.single;
      expect(write.method, 'POST');
      final body = jsonDecode(write.body);
      expect(body['seller_id'], 'student');
      expect(body['university_id'], 'school-b');
      expect(body['pickup_zone_id'], 'zone-b');
      expect(body['title'], 'Updated book');
      expect(f.repo.getListing('new-listing')?.title, 'Updated book');
    },
  );
  test(
    'edits own listing with ownership and status filters preserving existing photo',
    () async {
      final f = await fixture();
      await save(
        f.repo,
        id: 'listing-b',
        photo: 'https://test.invalid/book.jpg',
      );
      final write = f.requests.single;
      expect(write.method, 'PATCH');
      expect(write.url.queryParameters['seller_id'], 'eq.student');
      expect(write.url.queryParameters['university_id'], 'eq.school-b');
      expect(write.url.queryParameters['status'], 'eq.available');
      final body = jsonDecode(write.body) as Map;
      expect(body.keys, isNot(contains('seller_id')));
      expect(body.keys, isNot(contains('cover_image_url')));
      expect(f.repo.getListing('listing-b')?.title, 'Updated book');
    },
  );
  test(
    'zero-row edit is reported and keeps cached listing unchanged',
    () async {
      final f = await fixture(rejectUpdates: true);
      await expectLater(
        save(f.repo, id: 'listing-b'),
        throwsA(isA<Exception>()),
      );
      expect(f.repo.getListing('listing-b')?.title, 'Course book');
    },
  );
  test('cannot edit another seller listing', () async {
    final f = await fixture(sellerId: 'other-seller');
    await expectLater(save(f.repo, id: 'listing-b'), throwsStateError);
    expect(f.requests, isEmpty);
  });
}
