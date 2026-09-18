import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'listing_photo.dart';

class ListingPhotoStorage {
  ListingPhotoStorage(this.client);
  final SupabaseClient client;
  static const bucket = 'listing-images';

  Future<String> upload({
    required String universityId,
    required ListingPhoto photo,
  }) async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous || user.emailConfirmedAt == null) {
      throw StateError('Sign in before uploading photos.');
    }
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(universityId)) {
      throw ArgumentError('Invalid university.');
    }
    final random = Random.secure();
    final name = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '$universityId/${user.id}/$name.${photo.extension}';
    await client.storage
        .from(bucket)
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(contentType: photo.mimeType, upsert: false),
        );
    return path;
  }

  Future<String> resolve(String path) =>
      client.storage.from(bucket).createSignedUrl(path, 3600);
}
