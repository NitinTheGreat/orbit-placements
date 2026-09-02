import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_tokens.dart';

const Color launchGround = Color(0xFF11152A);
const Duration _markSettle = Duration(milliseconds: 620);
const Duration _liftDelay = Duration(milliseconds: 700);
const Duration _lift = Duration(milliseconds: 520);

class LaunchCurtain extends StatefulWidget {
  const LaunchCurtain({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchCurtain> createState() => _LaunchCurtainState();
}

class _LaunchCurtainState extends State<LaunchCurtain> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return widget.child;
    }

    if (prefersReducedMotion(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _done = true);
        }
      });
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child:
                Container(
                      color: launchGround,
                      alignment: Alignment.center,
                      child:
                          Image.asset(
                                'assets/brand/logo_final_foreground.png',
                                width: 148,
                                height: 148,
                                filterQuality: FilterQuality.medium,
                              )
                              .animate()
                              .scaleXY(
                                begin: 0.74,
                                end: 1,
                                duration: _markSettle,
                                curve: OrbitMotion.spring,
                              )
                              .rotate(
                                begin: -0.055,
                                end: 0,
                                duration: _markSettle,
                                curve: OrbitMotion.spring,
                              )
                              .fadeIn(duration: OrbitMotion.base)
                              .then(delay: const Duration(milliseconds: 80))
                              .scaleXY(
                                end: 1.18,
                                duration: _lift,
                                curve: OrbitMotion.settle,
                              )
                              .fadeOut(duration: _lift),
                    )
                    .animate(
                      onComplete: (_) {
                        if (mounted) {
                          setState(() => _done = true);
                        }
                      },
                    )
                    .fadeOut(
                      delay: _liftDelay,
                      duration: _lift,
                      curve: OrbitMotion.settle,
                    )
                    .slideY(
                      begin: 0,
                      end: -0.06,
                      delay: _liftDelay,
                      duration: _lift,
                      curve: OrbitMotion.settle,
                    ),
          ),
        ),
      ],
    );
  }
}
