import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.975,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduceMotion = prefersReducedMotion(context);
    final target = (_pressed && enabled && !reduceMotion) ? widget.scale : 1.0;

    return Semantics(
      button: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: target,
          duration: _pressed ? OrbitMotion.fast : OrbitMotion.base,
          curve: _pressed ? OrbitMotion.settle : OrbitMotion.spring,
          child: widget.child,
        ),
      ),
    );
  }
}
