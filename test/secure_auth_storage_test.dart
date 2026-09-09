import 'dart:async';
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

class DelayedWriteStorage extends FlutterSecureStorage {
  final started = Completer<void>();
  final release = Completer<void>();
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
  }) async {
    started.complete();
    await release.future;
    await super.write(key: key, value: value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  for (final verifier in [false, true]) {
    test(
      'sign-out removes an in-flight ${verifier ? 'verifier' : 'session'} write',
      () async {
        final storage = DelayedWriteStorage();
        final store = SecureAuthStore(sessionKey: 'project', storage: storage);
        final write = verifier
            ? SecurePkceStorage(store).setItem(
                key: SecureAuthStore.legacyVerifierKey,
                value: 'pending',
              )
            : store.persistSession('pending');
        await storage.started.future;
        final signOut = store.removePersistedSession();
        await Future<void>.delayed(Duration.zero);
        storage.release.complete();
        await Future.wait([write, signOut]);
        expect(await store.accessToken(), isNull);
        expect(
          await SecurePkceStorage(
            store,
          ).getItem(key: SecureAuthStore.legacyVerifierKey),
          isNull,
        );
      },
    );
  }
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
