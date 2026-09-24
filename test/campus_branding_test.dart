import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/app.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/data/models.dart';

class CampusRepository extends Repository {
  CampusRepository(this.school) : super.offline();
  final String school;
  @override
  String get schoolShortName => school;
  @override
  Profile get me => Profile(
    id: 'student',
    name: 'Student',
    initials: 'S',
    school: school == 'GMU'
        ? 'George Mason University'
        : 'George Washington University',
  );
}

void main() {
  for (final school in ['GMU', 'GWU']) {
    testWidgets(
      '$school sees its own brand without demo banner or school switcher',
      (tester) async {
        final repo = CampusRepository(school);
        await tester.pumpWidget(UnivMarketApp(repository: repo));
        await tester.pumpAndSettle();
        expect(find.text('${school}Market'), findsOneWidget);
        expect(find.text(repo.me.school), findsOneWidget);
        expect(find.textContaining('LOCAL DEMO'), findsNothing);
        expect(find.byType(DropdownButton<String>), findsNothing);
        expect(
          find.text(
            school == 'GMU'
                ? 'George Washington University'
                : 'George Mason University',
          ),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        repo.dispose();
      },
    );
  }
}
