import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/data/backend_config.dart';

void main() {
  test('accepts an HTTPS Supabase URL and publishable client key', () {
    final config = BackendConfig.validate(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
    expect(config.url, 'https://example.supabase.co');
  });

  test('rejects missing, insecure and credential-bearing project URLs', () {
    for (final url in [
      '',
      'http://example.supabase.co',
      'https://user:password@example.supabase.co',
      'https://example.supabase.co?token=private',
      'https://example.supabase.co/auth',
    ]) {
      expect(
        () => BackendConfig.validate(
          url: url,
          publishableKey: 'sb_publishable_test',
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'rejects secret keys and unsupported legacy tokens without leaking them',
    () {
      for (final key in ['', 'sb_secret_do_not_expose', 'eyJlegacyToken']) {
        try {
          BackendConfig.validate(
            url: 'https://example.supabase.co',
            publishableKey: key,
          );
          fail('Invalid client key was accepted');
        } on ArgumentError catch (error) {
          if (key.isNotEmpty) expect(error.toString(), isNot(contains(key)));
        }
      }
    },
  );
}
