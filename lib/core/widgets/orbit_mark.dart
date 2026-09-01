import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class OrbitMark extends StatelessWidget {
  const OrbitMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitTheme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrbitMarkPainter(
          ring: colors.borderStrong,
          body: colors.accent,
        ),
      ),
    );
  }
}

class _OrbitMarkPainter extends CustomPainter {
  const _OrbitMarkPainter({required this.ring, required this.body});

  final Color ring;
  final Color body;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * 1.05,
      ),
      ringPaint,
    );
    canvas.restore();

    canvas.drawCircle(center, size.width * 0.19, Paint()..color = body);
  }

  @override
  bool shouldRepaint(_OrbitMarkPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.body != body;
}
