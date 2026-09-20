import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/demo_repository.dart';
import 'package:univmarket_app/screens/home_screen.dart';

void main() {
  for (final scenario in [
    (const Size(320, 568), 1.3),
    (const Size(390, 844), 2.0),
  ]) {
    testWidgets(
      'phone screens support ${scenario.$1.width}px at ${scenario.$2}x text',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = scenario.$1;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scenario.$2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = await DemoRepository.open();
        await tester.pumpWidget(UnivMarketApp(repository: repo));
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
        final errors = <String>[];
        for (final path in [
          '/',
          '/search',
          '/sell',
          '/saved',
          '/inbox',
          '/listing/gmu-item-1',
          '/chat/gmu-welcome',
          '/profile',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          final error = tester.takeException();
          if (error != null) errors.add('$path: $error');
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        repo.dispose();
        expect(errors, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
