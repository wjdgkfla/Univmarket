import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'tab_bar.dart';

/// Shared scaffold for tab screens.
///
/// With a [title], the screen gets the iOS large-title pattern: a 34pt title
/// at the top of the content that scrolls under a translucent bar, and a
/// 17pt inline title that fades into that bar once the large one is gone.
class ScreenScaffold extends StatefulWidget {
  final Widget child;
  final bool scroll;
  final bool navClearance;
  final EdgeInsets padding;
  final String? title;
  final Widget? trailing;

  const ScreenScaffold({
    super.key,
    required this.child,
    this.scroll = true,
    this.navClearance = true,
    this.padding = EdgeInsets.zero,
    this.title,
    this.trailing,
  });

  static const double navClearanceHeight = AppTabBar.barHeight + 24;
  static const double barHeight = 44;

  @override
  State<ScreenScaffold> createState() => _ScreenScaffoldState();
}

class _ScreenScaffoldState extends State<ScreenScaffold> {
  bool _collapsed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    // The large title is roughly 50pt tall; collapse once it has scrolled off.
    final collapsed = n.metrics.pixels > 44;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomPad =
        (widget.navClearance ? ScreenScaffold.navClearanceHeight : 24.0) +
        MediaQuery.of(context).padding.bottom;
    final title = widget.title;
    final top = title == null ? topInset : topInset + ScreenScaffold.barHeight;

    final content = title == null
        ? widget.child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LargeTitle(title, trailing: widget.trailing),
              widget.child,
            ],
          );

    final body = widget.scroll
        ? SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: widget.padding.add(
              EdgeInsets.only(top: top, bottom: bottomPad),
            ),
            child: content,
          )
        : Padding(
            padding: widget.padding.add(
              EdgeInsets.only(top: top, bottom: bottomPad),
            ),
            child: content,
          );

    if (title == null) return Scaffold(body: body);

    final c = context.colors;
    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: body,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: topInset + ScreenScaffold.barHeight,
                  padding: EdgeInsets.only(top: topInset),
                  decoration: BoxDecoration(
                    color: c.bg.withValues(alpha: _collapsed ? 0.92 : 1),
                    border: Border(
                      bottom: BorderSide(
                        color: _collapsed ? c.line : c.bg.withValues(alpha: 0),
                        width: 0.5,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    // Only one copy of the title exists at rest, so screen
                    // readers and finders see a single heading.
                    child: _collapsed
                        ? Padding(
                            key: const ValueKey('inline'),
                            padding: const EdgeInsets.symmetric(horizontal: 56),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                                color: c.ink,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
