import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const nativeSecretStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class SecureAuthStore extends LocalStorage {
  SecureAuthStore({
    required this.sessionKey,
    this.storage = nativeSecretStorage,
  });
  Future<void> _pending = Future.value();

  // SDK auth events can overlap. Keep reads, writes and deletion in order;
  // a failed operation must not prevent a later sign-out from clearing data.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  final String sessionKey;
  final FlutterSecureStorage storage;
  static const legacyVerifierKey = 'supabase.auth.token-code-verifier';
  String verifierKey(String key) => '$sessionKey-pkce-$key';

  @override
  Future<void> initialize() => _serial(() async {
    final preferences = await SharedPreferences.getInstance();
    for (final pair in {
      sessionKey: sessionKey,
      legacyVerifierKey: verifierKey(legacyVerifierKey),
    }.entries) {
      final old = preferences.getString(pair.key);
      if (old == null) continue;
      final existing = await storage.read(key: pair.value);
      if (existing == null) {
        await storage.write(key: pair.value, value: old);
        if (await storage.read(key: pair.value) != old) {
          throw StateError(
            'Unable to protect the saved session. Please retry.',
          );
        }
      }
      if (!await preferences.remove(pair.key)) {
        throw StateError('Unable to finish session migration. Please retry.');
      }
    }
  });

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<String?> accessToken() => _serial(() => storage.read(key: sessionKey));
  @override
  Future<void> persistSession(String persistSessionString) => _serial(
    () => storage.write(key: sessionKey, value: persistSessionString),
  );
  @override
  Future<void> removePersistedSession() => _serial(() async {
    await storage.delete(key: sessionKey);
    await storage.delete(key: verifierKey(legacyVerifierKey));
  });
}

class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this.store);
  final SecureAuthStore store;
  @override
  Future<String?> getItem({required String key}) =>
      store._serial(() => store.storage.read(key: store.verifierKey(key)));
  @override
  Future<void> setItem({required String key, required String value}) =>
      store._serial(
        () => store.storage.write(key: store.verifierKey(key), value: value),
      );
  @override
  Future<void> removeItem({required String key}) =>
      store._serial(() => store.storage.delete(key: store.verifierKey(key)));
}
