import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:univmarket_app/auth/live_auth_gate.dart';

void main() {
  testWidgets('listens for warm links while initial link lookup is pending', (
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
    final initial = Completer<Uri?>();
    final links = StreamController<Uri>.broadcast();
    await tester.pumpWidget(
      LiveAuthGate(
        client: client,
        initialLink: () => initial.future,
        linkStream: links.stream,
      ),
    );
    links.add(
      Uri.parse('com.univmarket.app://auth-callback/?error=access_denied'),
    );
    await tester.pump();
    initial.complete(null);
    await tester.pumpAndSettle();
    expect(find.textContaining('invalid or expired'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await links.close();
  });
}
