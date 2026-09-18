import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/widgets/version_gate.dart';

void main() {
  Future<void> pumpGate(
    WidgetTester tester, {
    required int? build,
    required Future<MinimumVersion?> Function() fetch,
  }) async {
    await tester.pumpWidget(
      VersionGate(
        build: build,
        fetchMinimum: fetch,
        child: const MaterialApp(home: Text('signed-in app')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('build below the minimum is blocked with an update link', (
    tester,
  ) async {
    await pumpGate(
      tester,
      build: 1,
      fetch: () async =>
          (minBuild: 2, updateUrl: 'https://testflight.apple.com/join/x'),
    );
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Get the update'), findsOneWidget);
    expect(find.text('signed-in app'), findsNothing);
  });

  testWidgets('current build, failed check, or unknown build opens the app', (
    tester,
  ) async {
    await pumpGate(
      tester,
      build: 2,
      fetch: () async => (minBuild: 2, updateUrl: null),
    );
    expect(find.text('signed-in app'), findsOneWidget);

    await pumpGate(tester, build: 1, fetch: () async => throw Exception());
    expect(find.text('signed-in app'), findsOneWidget);

    await pumpGate(
      tester,
      build: null,
      fetch: () async => (minBuild: 5, updateUrl: null),
    );
    expect(find.text('signed-in app'), findsOneWidget);
  });

  testWidgets('check again lets an updated minimum through', (tester) async {
    var minimum = 3;
    await pumpGate(
      tester,
      build: 2,
      fetch: () async => (minBuild: minimum, updateUrl: null),
    );
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Get the update'), findsNothing);
    minimum = 2;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('signed-in app'), findsOneWidget);
  });
}
