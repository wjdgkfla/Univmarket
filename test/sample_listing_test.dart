import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/data/repository.dart';
import 'package:univmarket_app/screens/listing_detail_screen.dart';
import 'package:univmarket_app/widgets/listing_image.dart';

class SampleRepository extends Repository {
  SampleRepository() : super.offline();
  @override
  Listing? getListing(String id) => const Listing(
    id: 'sample-1',
    icon: 'book',
    title: 'Calculus textbook',
    price: 25,
    condition: Condition.good,
    zone: 'Fenwick Library',
    tag: 'Textbooks',
    trades: false,
    description: 'For preview only.',
    sellerId: 'sample-seller-george-mason',
  );
  @override
  Profile? getSeller(String id) => null;
}

void main() {
  testWidgets(
    'sample sellers are labeled and cannot receive messages or offers',
    (tester) async {
      final repo = SampleRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<Repository>.value(
          value: repo,
          child: const MaterialApp(home: ListingDetailScreen(id: 'sample-1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SAMPLE'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Message seller'), 300);
      expect(find.text('Sample seller'), findsOneWidget);
      for (final label in ['Message seller', 'Make offer']) {
        await tester.scrollUntilVisible(find.text(label), 150);
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'real listings without photos do not get sample imagery or label',
    (tester) async {
      final listing = Listing.fromJson({
        ...SampleRepository().getListing('x')!.toJson(),
        'sellerId': 'real-student',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: ListingImage(listing: listing),
          ),
        ),
      );
      expect(find.text('SAMPLE'), findsNothing);
      expect(find.byType(Image), findsNothing);
    },
  );
}
