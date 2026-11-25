import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A quiet, stationary doodle pattern behind the conversation history.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111B25)
          : const Color(0xFFEDF1F4),
      child: CustomPaint(
        painter: _ChatWallpaperPainter(
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
        child: child,
      ),
    ),
  );
}

class _ChatWallpaperPainter extends CustomPainter {
  const _ChatWallpaperPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : AppColors.accent).withValues(
        alpha: dark ? .035 : .045,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var row = -1; row * 88 < size.height + 40; row++) {
      for (var col = -1; col * 88 < size.width + 40; col++) {
        final kind = (col + row * 3) % 5;
        canvas.save();
        canvas.translate(
          col * 88.0 + (row.isOdd ? 44 : 0) + 20,
          row * 88.0 + 24,
        );
        canvas.rotate(((col * 7 + row * 11) % 7 - 3) * 0.12);
        final path = Path();
        switch (kind) {
          case 0: // Speech bubble.
            path
              ..moveTo(-10, -9)
              ..lineTo(10, -9)
              ..quadraticBezierTo(15, -9, 15, -4)
              ..lineTo(15, 5)
              ..quadraticBezierTo(15, 10, 10, 10)
              ..lineTo(-3, 10)
              ..lineTo(-11, 16)
              ..lineTo(-9, 10)
              ..quadraticBezierTo(-15, 10, -15, 5)
              ..lineTo(-15, -4)
              ..quadraticBezierTo(-15, -9, -10, -9);
          case 1: // Four-point sparkle.
            for (var i = 0; i < 8; i++) {
              final angle = i * math.pi / 4;
              final radius = i.isEven ? 14.0 : 4.5;
              final point = Offset(math.cos(angle), math.sin(angle)) * radius;
              if (i == 0) {
                path.moveTo(point.dx, point.dy);
              } else {
                path.lineTo(point.dx, point.dy);
              }
            }
            path.close();
          case 2: // Paper plane.
            path
              ..moveTo(-15, -5)
              ..lineTo(15, -13)
              ..lineTo(7, 15)
              ..lineTo(-1, 5)
              ..close()
              ..moveTo(-1, 5)
              ..lineTo(15, -13);
          case 3: // Small heart.
            path
              ..moveTo(0, 12)
              ..cubicTo(-25, -2, -10, -20, 0, -9)
              ..cubicTo(10, -20, 25, -2, 0, 12);
          case 4: // A checked planner page.
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                const Rect.fromLTWH(-12, -13, 24, 28),
                const Radius.circular(4),
              ),
              paint,
            );
            path
              ..moveTo(-6, -16)
              ..lineTo(-6, -10)
              ..moveTo(6, -16)
              ..lineTo(6, -10)
              ..moveTo(-6, 3)
              ..lineTo(-1, 8)
              ..lineTo(7, -1);
        }
        canvas.drawPath(path, paint);
        canvas.drawCircle(const Offset(31, 35), 1.5, paint);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChatWallpaperPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
