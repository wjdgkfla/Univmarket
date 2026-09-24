// Regression coverage for bug B2: search only ever looked at repo.listListings()
// client-side, which now holds just the newest page of the feed (see
// feed_pagination_test.dart) — a match on an older listing would come back
// empty even though the item is really there. searchListings() queries the
// server directly instead.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/data/repository.dart';
import 'demo_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({Repository repo, List<http.Request> requests})> _fixture() async {
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
            base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))),
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
          'university_id': 'school-a',
          'home_campus_id': 'campus-a',
        };
      } else if (path.endsWith('/universities')) {
        result = {'id': 'school-a', 'name': 'School A'};
      } else if (path.endsWith('/campuses')) {
        result = {'id': 'campus-a', 'university_id': 'school-a'};
      } else if (path.endsWith('/listings') && request.url.queryParameters.containsKey('or')) {
        result = [
          {
            'id': 'old-match',
            'university_id': 'school-a',
            'seller_id': 'someone-else',
            'title': 'A very old desk lamp',
            'price': 8,
            'category': 'Dorm',
            'condition': 'fair',
            'status': 'available',
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
  await client.auth.signInWithPassword(
    email: 'student@test.invalid',
    password: 'test-password',
  );
  final repo = Repository(client: client);
  await repo.initialized;
  expect(repo.bootstrapError, isNull);
  requests.clear();
  return (repo: repo, requests: requests);
}

void main() {
  test('searches the server, not just the loaded feed', () async {
    final f = await _fixture();
    final results = await f.repo.searchListings('lamp');
    expect(results.single.id, 'old-match');
    final request = f.requests.singleWhere(
      (r) => r.url.path.endsWith('/listings'),
    );
    expect(request.url.queryParameters['university_id'], 'eq.school-a');
    expect(request.url.queryParameters['status'], 'eq.available');
    expect(
      request.url.queryParameters['or'],
      '(title.ilike.%lamp%,description.ilike.%lamp%)',
    );
  });

  test('a comma or parenthesis in the query cannot break the filter', () async {
    final f = await _fixture();
    await f.repo.searchListings('desk, (lamp)');
    final request = f.requests.singleWhere(
      (r) => r.url.path.endsWith('/listings'),
    );
    expect(
      request.url.queryParameters['or'],
      isNot(contains(RegExp(r'[,(]lamp'))),
    );
    expect(request.url.queryParameters['or'], contains('desk   lamp'));
  });

  test('an empty query never hits the server', () async {
    final f = await _fixture();
    expect(await f.repo.searchListings('   '), isEmpty);
    expect(f.requests, isEmpty);
  });

  test('demo mode never hits the server', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await DemoRepository.open();
    expect(await repo.searchListings('anything'), isEmpty);
  });
}
