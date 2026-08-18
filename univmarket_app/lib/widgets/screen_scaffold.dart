import 'package:flutter/material.dart';

/// Shared scaffold: transparent background (so the app-level AmbientGlow
/// shows through), safe-area top padding, optional bottom clearance for
/// the floating pill nav which overlays tab screens.
class ScreenScaffold extends StatelessWidget {
  final Widget child;
  final bool scroll;
  final bool navClearance;
  final EdgeInsets padding;

  const ScreenScaffold({
    super.key,
    required this.child,
    this.scroll = true,
    this.navClearance = true,
    this.padding = EdgeInsets.zero,
  });

  static const double navClearanceHeight = 92;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomPad = navClearance ? navClearanceHeight : 0.0;

    final body = scroll
        ? SingleChildScrollView(
            padding: padding.add(EdgeInsets.only(bottom: bottomPad)),
            child: child,
          )
        : Padding(
            padding: padding.add(EdgeInsets.only(bottom: bottomPad)),
            child: child,
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: body,
      ),
    );
  }
}
