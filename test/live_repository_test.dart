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
            result = {
              'id': 'school-b',
              'name': 'Second University',
              'short_name': 'GWU',
            };
          } else if (path.endsWith('/campuses')) {
            result = {'id': 'campus-b', 'university_id': 'school-b'};
          } else if (path.endsWith('/pickup_zones')) {
            result = [
              {'id': 'zone-b', 'name': 'Campus B library'},
            ];
          } else if (path.endsWith('/favorites')) {
            // Two different queries share this table: _refreshFavorites'
            // own plain `listing_id` (drives the heart icon) and the feed's
            // embedded `listings(*)` (a saved item, reserved rather than
            // 'available', to prove it survives outside the paginated
            // available feed and without its id ever appearing in a URL).
            result = request.url.queryParameters['select'] == 'listing_id'
                ? [
                    {'listing_id': 'saved-reserved'},
                  ]
                : [
                    {
                      'listings': {
                        'id': 'saved-reserved',
                        'university_id': 'school-b',
                        'seller_id': 'someone-else',
                        'title': 'Reserved textbook',
                        'price': 5,
                        'category': 'Textbooks',
                        'condition': 'good',
                        'status': 'reserved',
                        'moderation_state': 'visible',
                        'deleted_at': null,
                      },
                    },
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
      expect(repo.schoolShortName, 'GWU');
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
      final feedRequests = requests
          .where((r) => r.url.path.endsWith('/listings'))
          .toList();
      // The paginated "available" page and "my own listings" are separate
      // plain-filter requests — neither embeds a list of ids, so neither's
      // URL grows with the marketplace or with how much I've saved/chatted
      // about. See 20260923... bug #5 in the audit.
      expect(feedRequests, hasLength(2));
      final availableRequest = feedRequests.singleWhere(
        (r) => r.url.queryParameters['status'] == 'eq.available',
      );
      expect(
        availableRequest.url.queryParameters['university_id'],
        'eq.school-b',
      );
      final mineRequest = feedRequests.singleWhere(
        (r) => r.url.queryParameters['seller_id'] == 'eq.student',
      );
      expect(mineRequest.url.queryParameters.containsKey('status'), isFalse);
      // Two different /favorites reads: _refreshFavorites' own plain read
      // (drives the heart icon) and the feed's embedded listings(*) join.
      final favoritesRequests = requests
          .where((r) => r.url.path.endsWith('/favorites'))
          .toList();
      expect(favoritesRequests, hasLength(2));
      final favoritesJoinRequest = favoritesRequests.singleWhere(
        (r) => r.url.queryParameters['select'] != 'listing_id',
      );
      expect(
        favoritesJoinRequest.url.queryParameters['user_id'],
        'eq.student',
      );
      // Saved (and chatted-about) items stay loaded after they are reserved,
      // pulled in by joining through favorites/conversations, never by
      // listing an id anywhere in a request.
      expect(
        repo.listListings().map((l) => l.id),
        containsAll(['listing-b', 'saved-reserved']),
      );
      expect(
        repo.listListings().firstWhere((l) => l.id == 'listing-b').imageSource,
        'https://test.invalid/book.jpg',
      );
    },
  );
}
