import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/data/models.dart';

Future<({Repository repo, List<http.Request> requests})> fixture({
  bool rejectUpdates = false,
  String sellerId = 'student',
}) async {
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'https://test.invalid',
    'public-test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
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
      if (path == '/auth/v1/token') {
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

