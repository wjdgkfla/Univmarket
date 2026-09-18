import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/auth/recovery_service.dart';
import 'package:univmarket_app/screens/password_recovery_screen.dart';

class FakeRecovery implements RecoveryService {
  String? email;
  String? password;
  bool fail = false;
  @override
  Future<void> sendResetEmail(String email) async {
    this.email = email;
  }

  @override
  Future<void> updatePassword(String password) async {
    if (fail) throw Exception('private details');
    this.password = password;
  }
}

void main() {
  testWidgets(
    'reset request requires email and presents a neutral delivery message',
    (tester) async {
      final service = FakeRecovery();
      await tester.pumpWidget(
        MaterialApp(home: PasswordRecoveryScreen(service: service)),
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(service.email, isNull);
      await tester.enterText(
        find.byKey(const Key('recovery-email')),
        ' Student@school.edu ',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(service.email, 'student@school.edu');
      expect(find.textContaining('If an account exists'), findsOneWidget);
    },
  );
  testWidgets(
    'new password must match confirmation and supports retry after failure',
    (tester) async {
      final service = FakeRecovery()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordRecoveryScreen(service: service, resetSession: true),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('recovery-password')),
        'long-password-123',
      );
      await tester.enterText(
        find.byKey(const Key('recovery-confirm')),
        'different-password',
      );
      await tester.tap(find.text('Update password'));
      await tester.pump();
      expect(service.password, isNull);
      await tester.enterText(
        find.byKey(const Key('recovery-confirm')),
        'long-password-123',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to update'), findsOneWidget);
      expect(find.textContaining('private details'), findsNothing);
      service.fail = false;
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(service.password, 'long-password-123');
      expect(
        find.text('Password updated. Sign in with your new password.'),
        findsOneWidget,
      );
    },
  );
}
