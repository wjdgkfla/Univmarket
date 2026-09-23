import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/auth/auth_service.dart';
import 'package:univmarket_app/screens/auth_screen.dart';

class FakeAuth implements AuthService {
  String? email;
  String? password;
  String? name;
  String? confirmedCode;
  int resends = 0;
  bool registered = false;
  bool fail = false;
  bool failCode = false;
  @override
  Future<void> signIn(String email, String password) async {
    if (fail) throw Exception('private server details');
    this.email = email;
    this.password = password;
  }

  @override
  Future<void> signUp(String email, String password, String name) async {
    registered = true;
    this.name = name;
    this.email = email;
    this.password = password;
  }

  @override
  Future<void> confirmSignUp(String email, String code) async {
    if (failCode) throw Exception('invalid code');
    confirmedCode = code;
  }

  @override
  Future<void> resendSignUpCode(String email) async => resends++;
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
      ' Student@GMU.edu ',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'password1234',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(auth.email, 'student@gmu.edu');
    expect(auth.password, 'password1234');
  });

  testWidgets('only launch school emails can sign in or sign up', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    for (final email in [
      'student@umd.edu',
      'student@mail.gmu.edu',
      'student@fenwick.edu',
      'student@gmu.edu.attacker.test',
    ]) {
      await tester.enterText(find.byKey(const Key('auth-email')), email);
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'password1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      expect(find.text('Use your @gmu.edu or @gwu.edu email.'), findsOneWidget);
    }
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(auth.email, isNull);
    expect(auth.registered, isFalse);

    await tester.enterText(find.byKey(const Key('auth-email')), 'a@gwu.edu');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    // A name is required to create an account.
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(auth.registered, isFalse);
    await tester.enterText(find.byKey(const Key('auth-name')), '  Jordan Lee ');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(auth.email, 'a@gwu.edu');
    expect(auth.name, 'Jordan Lee');
  });

  testWidgets(
    'sign-up moves to code entry, and a sign-in failure remains retryable',
    (tester) async {
      final auth = FakeAuth()..fail = true;
      await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'student@gmu.edu',
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
      await tester.enterText(find.byKey(const Key('auth-name')), 'Jordan Lee');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(auth.registered, isTrue);
      // No clickable link: a mail security scanner can't burn it, and the
      // student only ever sees a code to type in.
      expect(
        find.textContaining('code we sent to student@gmu.edu'),
        findsOneWidget,
      );
      expect(find.textContaining('confirmation link'), findsNothing);
    },
  );

  testWidgets('a wrong code stays retryable; a full code auto-submits', (
    tester,
  ) async {
    final auth = FakeAuth();
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-name')), 'Jordan Lee');
    await tester.enterText(find.byKey(const Key('auth-email')), 'a@gwu.edu');
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'password1234',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    auth.failCode = true;
    await tester.enterText(find.byKey(const Key('auth-code')), '000000');
    await tester.pumpAndSettle();
    expect(find.textContaining('incorrect or has expired'), findsOneWidget);
    expect(auth.confirmedCode, isNull);

    auth.failCode = false;
    await tester.enterText(find.byKey(const Key('auth-code')), '123456');
    await tester.pumpAndSettle();
    expect(auth.confirmedCode, '123456');

    // "Back" abandons the pending sign-up and returns to the form.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
  });
}
