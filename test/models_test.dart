import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/data/models.dart';

// Plain-Dart unit test — no plugins, no network — kept in test/ since it
// can actually run under `flutter test`. See widget_test.dart for why the
// UI flows moved to integration_test/app_test.dart instead.
void main() {
  test('Condition.label matches the DB condition values', () {
    expect(Condition.fair.label, 'Fair');
    expect(Condition.good.label, 'Good');
    expect(Condition.likeNew.label, 'Like New');
  });
}
