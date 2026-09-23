// Regression coverage for bug #5 in the audit: the marketplace feed had no
// paging (silently capped at Postgrest's default max_rows) and embedded
// every saved/chatted listing id straight into the request URL, which grows
// without bound as a student's history grows. See
// supabase/migrations/... and lib/data/repository.dart's _refreshListings.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/data/repository.dart';

Map<String, dynamic> _listingRow(int i) => {
  'id': 'listing-$i',
  'university_id': 'school-a',
  'seller_id': 'someone-else',
  'title': 'Item $i',
  'price': 10,
  'category': 'Textbooks',
  'condition': 'good',
  'status': 'available',
  'created_at': DateTime(2026, 1, 1)
      .subtract(Duration(minutes: i))
      .toIso8601String(),
};

void main() {
  test('a full page of available listings reports more to load, and paging in fetches the next page', () async {
    // 300 listings (a full page) so the first fetch reports more, then 40
    // more so the second, smaller page reports none.
    final firstPage = [for (var i = 0; i < 300; i++) _listingRow(i)];
    final secondPage = [for (var i = 300; i < 340; i++) _listingRow(i)];
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://test.invalid',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        Object result = [];
        final path = request.url.path;
        final params = request.url.queryParameters;
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
            'university_id': 'school-a',
            'home_campus_id': 'campus-a',
          };
        } else if (path.endsWith('/universities')) {
          result = {'id': 'school-a', 'name': 'School A'};
        } else if (path.endsWith('/campuses')) {
          result = {'id': 'campus-a', 'university_id': 'school-a'};
        } else if (path.endsWith('/pickup_zones')) {
          result = [];
        } else if (path.endsWith('/favorites') || path.endsWith('/blocks')) {
          result = [];
        } else if (path.endsWith('/listings')) {
          if (params.containsKey('or')) {
            // The small "mine + saved/chatted" page: nothing here.
            result = [];
          } else if (params['created_at'] == 'lt.${firstPage.last['created_at']}') {
            result = secondPage;
          } else {
            // A real database just returns up to however many rows were
            // asked for; simulate that (rather than always the fixed first
            // page) so a refresh's growing limit is actually exercised.
            final pool = [...firstPage, ...secondPage];
            final limit = int.tryParse(params['limit'] ?? '') ?? 300;
            result = pool.take(limit).toList();
          }
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
    expect(repo.listListings(), hasLength(300));
    expect(repo.hasMoreListings, isTrue);

    await repo.loadMoreListings();
    expect(repo.listListings(), hasLength(340));
    expect(repo.hasMoreListings, isFalse);

    // Loading more again is a no-op: no third page exists to ask for.
    final before = requests.length;
    await repo.loadMoreListings();
    expect(requests.length, before);

    // Bug B6: a refresh (pull-to-refresh, the periodic timer, reopening the
    // app) used to always re-request just one page, throwing away whatever
    // extra pages loadMoreListings had already fetched.
    await repo.refreshMarketplace();
    expect(repo.listListings(), hasLength(340));
    // "mine" also hits /listings without an 'or' param but never sets a
    // limit at all — match on 'status' to get the paginated request itself.
    final refreshRequest = requests.lastWhere(
      (r) => r.url.queryParameters['status'] == 'eq.available',
    );
    expect(refreshRequest.url.queryParameters['limit'], '340');
  });
}
