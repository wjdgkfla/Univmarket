import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/auth/live_auth_gate.dart';
import 'package:univmarket_app/auth/auth_browser_location.dart';

class MemoryVerifier extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  testWidgets(
    'PKCE recovery cleans callback and remount restores password form without replay',
    (tester) async {
      final storage = MemoryVerifier();
      final requests = <http.Request>[];
      final token =
          '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'student', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://test.invalid',
          'test-key',
          authOptions: AuthClientOptions(
            autoRefreshToken: false,
            authFlowType: AuthFlowType.pkce,
            pkceAsyncStorage: storage,
          ),
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/recover')) {
              return http.Response('{}', 200);
            }
            if (request.url.path.endsWith('/token')) {
              return http.Response(
                jsonEncode({
                  'access_token': token,
                  'refresh_token': 'fake-refresh',
                  'expires_in': 3600,
                  'token_type': 'bearer',
                  'user': {
                    'id': 'student',
                    'aud': 'authenticated',
                    'app_metadata': {},
                    'user_metadata': {},
                    'created_at': '2026-01-01T00:00:00Z',
                    'email_confirmed_at': '2026-01-01T00:00:00Z',
                    'is_anonymous': false,
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            throw StateError('Unexpected request: ${request.url.path}');
          }),
        ),
      ))!;
      addTearDown(() => tester.runAsync(client.dispose));
      await client.auth.resetPasswordForEmail('student@example.edu');
      var current = Uri.parse('https://app.example/?code=one-use-code');
      final location = AuthBrowserLocation(
        read: () => current,
        replace: (uri) async {
          current = uri;
        },
      );
      Widget gate() => LiveAuthGate(
        client: client,
        initialLink: () async => current,
        linkStream: const Stream.empty(),
        browserLocation: location,
      );
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery-password')), findsOneWidget);
      expect(current.toString(), 'https://app.example/?recover=1');
      expect(storage.values, isEmpty);
      expect(requests.last.url.queryParameters['grant_type'], 'pkce');
      expect(jsonDecode(requests.last.body)['auth_code'], 'one-use-code');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery-password')), findsOneWidget);
      expect(requests.map((r) => r.url.path), [
        '/auth/v1/recover',
        '/auth/v1/token',
      ]);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
