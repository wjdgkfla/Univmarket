/// Validated public client configuration. Never includes server credentials.
class BackendConfig {
  const BackendConfig._(this.url, this.publishableKey);

  final String url;
  final String publishableKey;

  factory BackendConfig.validate({
    required String url,
    required String publishableKey,
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError('SUPABASE_URL must be an HTTPS project origin.');
    }
    if (!RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(publishableKey)) {
      throw ArgumentError(
        'SUPABASE_PUBLISHABLE_KEY must be a publishable client key.',
      );
    }
    return BackendConfig._(uri.origin, publishableKey);
  }
}
