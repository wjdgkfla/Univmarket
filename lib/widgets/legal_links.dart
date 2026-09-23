import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Published from site/ by .github/workflows/pages.yml.
const privacyUrl = 'https://wjdgkfla.github.io/Univmarket/privacy.html';
const termsUrl = 'https://wjdgkfla.github.io/Univmarket/terms.html';
const supportEmail = 'univmarket.app@gmail.com';

/// Opens a policy page in the in-app browser, or [supportEmail] in Mail.
Future<void> openLegalLink(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final opened = await launchUrl(
    uri,
    mode: uri.scheme == 'mailto'
        ? LaunchMode.externalApplication
        : LaunchMode.inAppBrowserView,
  ).catchError((Object _) => false);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uri.scheme == 'mailto'
              ? 'Email us at $supportEmail'
              : 'Could not open the page. Visit $url',
        ),
      ),
    );
  }
}
