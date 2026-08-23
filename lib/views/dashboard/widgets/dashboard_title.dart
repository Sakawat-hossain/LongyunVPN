import 'dart:async';

import 'package:longyunvpn/common/common.dart';
import 'package:flutter/material.dart';

/// The Dashboard app-bar title, which greets with the brand and then settles.
///
/// It shows "LongyunVPN" on arrival, holds it briefly, then crosses to
/// "Dashboard" and stays there. Deliberately not a loop: the app-bar title is
/// what tells you which page you are on, so something that keeps changing under
/// you costs orientation and pulls the eye away from the cards below — and it
/// would repaint forever for no benefit. Playing once per visit keeps the
/// flourish and none of that; navigating back to the tab plays it again.
class DashboardTitle extends StatefulWidget {
  const DashboardTitle({super.key});

  /// How long the brand stays before handing over.
  static const _hold = Duration(milliseconds: 1400);
  static const _crossFade = Duration(milliseconds: 420);

  @override
  State<DashboardTitle> createState() => _DashboardTitleState();
}

class _DashboardTitleState extends State<DashboardTitle> {
  bool _showBrand = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(DashboardTitle._hold, () {
      if (mounted) setState(() => _showBrand = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _showBrand ? appName : context.appLocalizations.dashboard;
    return AnimatedSwitcher(
      duration: DashboardTitle._crossFade,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // The outgoing word rises out and the incoming one lifts into place, so
      // the two never sit on top of each other mid-fade.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: Text(
        label,
        // Keyed so AnimatedSwitcher treats the two words as different children
        // rather than one widget whose text happened to change.
        key: ValueKey(_showBrand),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
