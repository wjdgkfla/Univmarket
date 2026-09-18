import 'package:flutter/services.dart';

/// Browser navigation only. The recovery marker selects a screen; it grants no
/// permissions and is ignored without an authenticated session.
class AuthBrowserLocation {
  AuthBrowserLocation({
    Uri Function()? read,
    Future<void> Function(Uri)? replace,
  }) : read = read ?? (() => Uri.base),
       replace =
           replace ??
           ((uri) => SystemNavigator.routeInformationUpdated(
             uri: uri,
             replace: true,
           ));

  final Uri Function() read;
  final Future<void> Function(Uri) replace;

  bool get recoveryRequested => read().queryParameters['recover'] == '1';

  Future<void> finishCallback({required bool recovering}) {
    // Callback routes are dedicated to auth; discard callback data entirely.
    final current = read();
    return replace(
      Uri(
        scheme: current.scheme,
        host: current.host,
        port: current.hasPort ? current.port : null,
        path: '/',
        queryParameters: recovering ? {'recover': '1'} : null,
      ),
    );
  }
}
