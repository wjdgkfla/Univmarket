import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/auth/auth_browser_location.dart';

void main() {
  test(
    'consumed callback removes secrets and retains only recovery intent',
    () async {
      var uri = Uri.parse(
        'https://app.example/?code=single-use#error_description=detail',
      );
      final location = AuthBrowserLocation(
        read: () => uri,
        replace: (next) async {
          uri = next;
        },
      );
      await location.finishCallback(recovering: true);
      expect(uri.toString(), 'https://app.example/?recover=1');
      expect(location.recoveryRequested, isTrue);
      await location.finishCallback(recovering: false);
      expect(uri.toString(), 'https://app.example/');
    },
  );
}
