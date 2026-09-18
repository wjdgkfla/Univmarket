import 'dart:convert';
import 'dart:typed_data';

class ListingPhoto {
  ListingPhoto._(this.bytes, this.mimeType, this.extension);
  static const maxBytes = 1500000;
  final Uint8List bytes;
  final String mimeType;
  final String extension;

  factory ListingPhoto.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('Choose a photo smaller than 1.5 MB.');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return ListingPhoto._(bytes, 'image/jpeg', 'jpg');
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      return ListingPhoto._(bytes, 'image/png', 'png');
    }
    throw ArgumentError('Choose a JPEG or PNG photo.');
  }

  factory ListingPhoto.fromDataUri(String source) {
    // Bound allocation before decoding externally supplied data.
    if (source.length > maxBytes * 4 ~/ 3 + 100) {
      throw ArgumentError('Photo is too large.');
    }
    final data = Uri.parse(source).data;
    if (data == null || !data.isBase64) {
      throw ArgumentError('Choose a JPEG or PNG photo.');
    }
    final photo = ListingPhoto.fromBytes(data.contentAsBytes());
    if (data.mimeType != photo.mimeType) {
      throw ArgumentError('Photo format does not match its contents.');
    }
    return photo;
  }

  String get dataUri => 'data:$mimeType;base64,${base64Encode(bytes)}';
}
