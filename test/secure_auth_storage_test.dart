import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:univmarket_app/auth/secure_auth_storage.dart';

class BrokenWriteStorage extends FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  test('migrates session and verifier then removes plaintext copies', () async {
    SharedPreferences.setMockInitialValues({
      'sb-project-auth-token': 'session',
      SecureAuthStore.legacyVerifierKey: 'verifier',
      'demo': 'keep',
    });
    final store = SecureAuthStore(sessionKey: 'sb-project-auth-token');
    await store.initialize();
    expect(await store.accessToken(), 'session');
    expect(
      await SecurePkceStorage(
        store,
      ).getItem(key: SecureAuthStore.legacyVerifierKey),
      'verifier',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), {'demo'});
    await store.removePersistedSession();
    expect(await store.hasAccessToken(), isFalse);
    expect(
      await SecurePkceStorage(
        store,
      ).getItem(key: SecureAuthStore.legacyVerifierKey),
      isNull,
    );
  });
  test('failed secure write preserves legacy session', () async {
    SharedPreferences.setMockInitialValues({
      'sb-project-auth-token': 'session',
    });
    final store = SecureAuthStore(
      sessionKey: 'sb-project-auth-token',
      storage: BrokenWriteStorage(),
    );
    await expectLater(store.initialize(), throwsStateError);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'sb-project-auth-token',
      ),
      'session',
    );
  });
  test('projects isolate stored sessions and verifiers', () async {
    final a = SecureAuthStore(sessionKey: 'project-a');
    final b = SecureAuthStore(sessionKey: 'project-b');
    await a.persistSession('a');
    await SecurePkceStorage(a).setItem(key: 'verifier', value: 'secret');
    expect(await b.accessToken(), isNull);
    expect(await SecurePkceStorage(b).getItem(key: 'verifier'), isNull);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
