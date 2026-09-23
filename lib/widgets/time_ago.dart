const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "just now", "5m ago", "3h ago", "2d ago", then a date ("Sep 23", with the
/// year once it is not this year). [now] is injectable for tests.
String timeAgo(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = time.toLocal();
  final elapsed = current.difference(local);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  final date = '${_months[local.month - 1]} ${local.day}';
  return local.year == current.year ? date : '$date, ${local.year}';
}
