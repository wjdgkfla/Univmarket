import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/tokens.dart';

typedef MinimumVersion = ({int minBuild, String? updateUrl});

/// Shows "Update required" when this install's build number is below the
/// server's `app_config.min_build`. If the check cannot complete (offline,
/// unparsable build), the app opens: the server enforces all access rules,
/// this only stops outdated installs.
// ponytail: checked once per launch; add a resume check if long-lived
// sessions on old builds become a problem.
class VersionGate extends StatefulWidget {
  const VersionGate({
    super.key,
    required this.build,
    required this.fetchMinimum,
    required this.child,
  });
  final int? build;
  final Future<MinimumVersion?> Function() fetchMinimum;
  final Widget child;

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  MinimumVersion? _required;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    MinimumVersion? minimum;
    try {
      minimum = await widget.fetchMinimum();
    } catch (_) {}
    if (!mounted) return;
    final build = widget.build;
    setState(() {
      _checking = false;
      _required = minimum != null && build != null && build < minimum.minBuild
          ? minimum
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checking && _required == null) return widget.child;
    final url = _required?.updateUrl;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brandTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _checking
                ? const CircularProgressIndicator.adaptive()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.arrow_down_circle, size: 44),
                      const SizedBox(height: 16),
                      const Text(
                        'Update required',
                        style: TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This version of the app is no longer supported. Install the latest version to continue.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (url != null)
                        FilledButton(
                          onPressed: () => launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: const Text('Get the update'),
                        ),
                      TextButton(
                        onPressed: _check,
                        child: const Text('Check again'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
