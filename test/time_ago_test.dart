import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/widgets/time_ago.dart';

void main() {
  test('relative times read like a marketplace', () {
    final now = DateTime(2026, 9, 23, 12);
    String ago(Duration d) => timeAgo(now.subtract(d), now: now);
    expect(ago(const Duration(seconds: 20)), 'just now');
    expect(ago(const Duration(minutes: 5)), '5m ago');
    expect(ago(const Duration(hours: 3)), '3h ago');
    expect(ago(const Duration(days: 2)), '2d ago');
    expect(ago(const Duration(days: 10)), 'Sep 13');
    expect(timeAgo(DateTime(2025, 12, 31), now: now), 'Dec 31, 2025');
    // A server clock slightly ahead of the phone never shows a future time.
    expect(timeAgo(now.add(const Duration(minutes: 2)), now: now), 'just now');
  });
}
