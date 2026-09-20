import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/auth/auth_service.dart';
import 'package:univmarket_app/auth/live_auth_gate.dart';
import 'package:univmarket_app/auth/recovery_service.dart';
import 'auth_pkce_test.dart' show MemoryVerifier;

void main() {
  testWidgets('cached legacy identity returns to welcome without loading data', (
    tester,
  ) async {
    final requests = <String>[];
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'legacy', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
    final client = (await tester.runAsync(() async {
      final client = SupabaseClient(
        'https://test.invalid',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r.url.path);
          if (r.url.path != '/auth/v1/token') {
            return http.Response('{"message":"not allowed"}', 403);
          }
          return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'test-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': {
                'id': 'legacy',
                'email': 'maya@fenwick.edu',
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
        }),
      );
      await client.auth.signInWithPassword(
        email: 'maya@fenwick.edu',
        password: 'test-password',
      );
      return client;
    }))!;
    addTearDown(() => tester.runAsync(client.dispose));
    await tester.pumpWidget(
      LiveAuthGate(
        client: client,
        initialLink: () async => null,
        linkStream: const Stream.empty(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to UnivMarket'), findsOneWidget);
    expect(requests, ['/auth/v1/token']);
    await tester.pumpWidget(const SizedBox());
  });

  test('registration sends the native confirmation callback', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://test.invalid',
      'key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryVerifier(),
      ),
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode({
            'id': 'student',
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-01-01T00:00:00Z',
          }),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await SupabaseAuthService(
      client,
    ).signUp('student@gmu.edu', 'a-long-password');
    expect(
      requests.single.url.queryParameters['redirect_to'],
      nativeAuthCallback,
    );
  });

  testWidgets(
    'fresh install opens welcome with real sign-in and registration choices',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://test.invalid',
          'key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ))!;
      addTearDown(() => tester.runAsync(client.dispose));
      await tester.pumpWidget(
        LiveAuthGate(
          client: client,
          initialLink: () async => null,
          linkStream: const Stream.empty(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome to UnivMarket'), findsOneWidget);
      expect(find.byKey(const Key('auth-email')), findsNothing);
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
