import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/auth/live_auth_gate.dart';

void main() {
  testWidgets(
    'cold-start recovery opens password form without loading marketplace',
    (tester) async {
      final paths = <String>[];
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://test.invalid',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            paths.add(request.url.path);
            return http.Response(
              jsonEncode({
                'id': 'student',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
                'email_confirmed_at': '2026-01-01T00:00:00Z',
                'is_anonymous': false,
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ))!;
      addTearDown(() => tester.runAsync(client.dispose));
      final token = [
        base64Url.encode(utf8.encode('{"alg":"HS256"}')),
        base64Url.encode(
          utf8.encode(
            jsonEncode({
              'sub': 'student',
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            }),
          ),
        ),
        'signature',
      ].join('.');
      final callback = Uri(
        scheme: 'com.univmarket.app',
        host: 'auth-callback',
        path: '/',
        fragment: Uri(
          queryParameters: {
            'access_token': token,
            'refresh_token': 'test-refresh',
            'expires_in': '3600',
            'token_type': 'bearer',
            'type': 'recovery',
          },
        ).query,
      );
      await tester.pumpWidget(
        LiveAuthGate(
          client: client,
          initialLink: () async => callback,
          linkStream: const Stream.empty(),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(find.byKey(const Key('recovery-password')), findsOneWidget);
      expect(paths, ['/auth/v1/user']);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed recovery callback can be reopened successfully', (
    tester,
  ) async {
    final paths = <String>[];
    final links = StreamController<Uri>.broadcast();
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://test.invalid',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (paths.length == 1) {
            return http.Response(
              '{"message":"Temporary request failure"}',
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'student',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
              'email_confirmed_at': '2026-01-01T00:00:00Z',
              'is_anonymous': false,
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    ))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final token = [
      base64Url.encode(utf8.encode('{"alg":"HS256"}')),
      base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': 'student',
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          }),
        ),
      ),
      'signature',
    ].join('.');
    final callback = Uri(
      scheme: 'com.univmarket.app',
      host: 'auth-callback',
      path: '/',
      fragment: Uri(
        queryParameters: {
          'access_token': token,
          'refresh_token': 'test-refresh',
          'expires_in': '3600',
          'token_type': 'bearer',
          'type': 'recovery',
        },
      ).query,
    );
    await tester.pumpWidget(
      LiveAuthGate(
        client: client,
        initialLink: () async => callback,
        linkStream: links.stream,
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(find.textContaining('invalid or expired'), findsOneWidget);
    links.add(callback);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recovery-password')), findsOneWidget);
    expect(paths, ['/auth/v1/user', '/auth/v1/user']);
    await tester.pumpWidget(const SizedBox());
    await links.close();
  });
  testWidgets('expired callback displays a generic recoverable error', (
    tester,
  ) async {
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://test.invalid',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final callback = Uri.parse(
      'com.univmarket.app://auth-callback/?error=access_denied&error_description=private-server-detail',
    );
    await tester.pumpWidget(
      LiveAuthGate(
        client: client,
        initialLink: () async => callback,
        linkStream: const Stream.empty(),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(find.textContaining('invalid or expired'), findsOneWidget);
    expect(find.textContaining('private-server-detail'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
