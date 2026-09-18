import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/auth/auth_service.dart';
import 'package:univmarket_app/screens/auth_screen.dart';

class FakeAuth implements AuthService {
  String? email;
  String? password;
  bool registered = false;
  bool fail = false;
  @override
  Future<void> signIn(String email, String password) async {
    if (fail) throw Exception('private server details');
    this.email = email;
    this.password = password;
  }

  @override
  Future<void> signUp(String email, String password) async {
    registered = true;
    this.email = email;
    this.password = password;
  }
}

void main() {
  testWidgets('sign-in validates fields and submits normalized email', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(auth.email, isNull);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      ' Student@School.edu ',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'password1234',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(auth.email, 'student@school.edu');
    expect(auth.password, 'password1234');
  });

  testWidgets(
    'sign-up asks for email confirmation and failures remain retryable',
    (tester) async {
      final auth = FakeAuth()..fail = true;
      await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'student@school.edu',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'password1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('private server details'), findsNothing);
      expect(find.textContaining('Unable to sign in'), findsOneWidget);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(auth.registered, isTrue);
      expect(find.textContaining('Check your email'), findsOneWidget);
    },
  );
}
