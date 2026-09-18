import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/data/models.dart';
import 'package:univmarket_app/widgets/listing_image.dart';

void main() {
  testWidgets(
    'remote listing photos use a network image rather than asset lookup',
    (tester) async {
      const listing = Listing(
        id: 'one',
        icon: 'book',
        title: 'Book',
        price: 10,
        condition: Condition.good,
        zone: 'Library',
        tag: 'Textbooks',
        trades: false,
        description: 'Book',
        sellerId: 'seller',
        imageSource: 'https://test.invalid/book.jpg',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: ListingImage(listing: listing),
          ),
        ),
      );
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<NetworkImage>(),
      );
    },
  );
}
