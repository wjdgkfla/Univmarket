import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/data/repository.dart';

void main() {
  test(
    'signed-out repository does not call profile RPC or read marketplace data',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://test.invalid',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests++;
          return http.Response('[]', 200, request: request);
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client: client);
      addTearDown(repo.dispose);
      await repo.initialized;
      expect(repo.bootstrapError, contains('confirmed email account'));
      expect(requests, 0);
      expect(repo.listListings(), isEmpty);
    },
  );
  test(
    'live bootstrap uses profile membership for campus, zones and feed',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
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
                      'exp':
                          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
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
                'seller_id': 'seller-b',
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
      expect(repo.me.school, 'Second University');
      expect(repo.universityId, 'school-b');
      expect(repo.pickupZones, ['Campus B library']);
      final uniRequest = requests.singleWhere(
        (r) => r.url.path.endsWith('/universities'),
      );
      expect(uniRequest.url.queryParameters['id'], 'eq.school-b');
      expect(uniRequest.url.queryParameters.containsKey('slug'), isFalse);
      final campusRequest = requests.singleWhere(
        (r) => r.url.path.endsWith('/campuses'),
      );
      expect(campusRequest.url.queryParameters['university_id'], 'eq.school-b');
      expect(campusRequest.url.queryParameters['id'], 'eq.campus-b');
      final zoneRequest = requests.singleWhere(
        (r) => r.url.path.endsWith('/pickup_zones'),
      );
      expect(zoneRequest.url.queryParameters['campus_id'], 'eq.campus-b');
      final feedRequest = requests.singleWhere(
        (r) => r.url.path.endsWith('/listings'),
      );
      expect(feedRequest.url.queryParameters['university_id'], 'eq.school-b');
      expect(
        feedRequest.url.queryParameters['or'],
        '(status.eq.available,seller_id.eq.student)',
      );
      expect(repo.listListings().single.universityId, 'school-b');
      expect(
        repo.listListings().single.imageSource,
        'https://test.invalid/book.jpg',
      );
    },
  );
}
