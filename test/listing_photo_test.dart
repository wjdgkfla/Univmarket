import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/data/listing_photo.dart';

void main() {
  test('detects PNG without labelling it JPEG and round trips bytes', () {
    final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]);
    final photo = ListingPhoto.fromBytes(bytes);
    expect(photo.mimeType, 'image/png');
    expect(ListingPhoto.fromDataUri(photo.dataUri).bytes, bytes);
    expect(
      () => ListingPhoto.fromDataUri(
        photo.dataUri.replaceFirst('image/png', 'image/jpeg'),
      ),
      throwsArgumentError,
    );
  });
  test('rejects unsupported and oversized photo input', () {
    expect(
      () => ListingPhoto.fromBytes(Uint8List.fromList([1, 2, 3])),
      throwsArgumentError,
    );
    expect(
      () => ListingPhoto.fromBytes(Uint8List(ListingPhoto.maxBytes + 1)),
      throwsArgumentError,
    );
  });
}
