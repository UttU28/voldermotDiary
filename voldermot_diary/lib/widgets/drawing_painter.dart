import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../models/animated_stroke.dart';

class DrawingPainter extends CustomPainter {
  final List<AnimatedStroke> strokes;
  final List<StrokePoint> currentStroke;
  final List<Offset> eraserTrail;
  final double eraserTrailOpacity;
  final String strokeColor;
  final double strokeWidth;
  final Size canvasSize;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.eraserTrail,
    required this.eraserTrailOpacity,
    required this.strokeColor,
    required this.strokeWidth,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final animatedStroke in strokes) {
      final visiblePoints = animatedStroke.visiblePoints;
      if (visiblePoints.isNotEmpty) {
        _drawStroke(canvas, visiblePoints, animatedStroke.stroke.color, animatedStroke.stroke.width);
      }
    }

    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, strokeColor, strokeWidth, withGlow: true);
    }

    if (eraserTrail.length > 1 && eraserTrailOpacity > 0) {
      _drawEraserTrail(canvas, eraserTrail, eraserTrailOpacity);
    }
  }

  void _drawEraserTrail(Canvas canvas, List<Offset> trail, double opacity) {
    if (trail.length < 2 || opacity <= 0) return;

    final path = Path();
    path.moveTo(trail[0].dx, trail[0].dy);

    for (int i = 1; i < trail.length; i++) {
      if (i == 1) {
        path.lineTo(trail[i].dx, trail[i].dy);
      } else {
        final prevPoint = trail[i - 1];
        final currentPoint = trail[i];
        final controlX = (prevPoint.dx + currentPoint.dx) / 2;
        final controlY = (prevPoint.dy + currentPoint.dy) / 2;
        path.quadraticBezierTo(prevPoint.dx, prevPoint.dy, controlX, controlY);
      }
    }

    final baseOpacity = 0.3 * opacity;
    final trailPaint = Paint()
      ..color = Colors.white.withOpacity(baseOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, trailPaint);
  }

  void _drawStroke(Canvas canvas, List<StrokePoint> points, String color, double width, {bool withGlow = false}) {
    if (points.length < 2) return;

    final screenPoints = points.map((p) => Offset(
      p.x * canvasSize.width,
      p.y * canvasSize.height,
    )).toList();

    final path = Path();
    path.moveTo(screenPoints[0].dx, screenPoints[0].dy);

    for (int i = 1; i < screenPoints.length; i++) {
      if (i == 1) {
        path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
      } else {
        final prevPoint = screenPoints[i - 1];
        final currentPoint = screenPoints[i];
        final controlX = (prevPoint.dx + currentPoint.dx) / 2;
        final controlY = (prevPoint.dy + currentPoint.dy) / 2;
        path.quadraticBezierTo(prevPoint.dx, prevPoint.dy, controlX, controlY);
      }
    }

    if (withGlow) {
      final glowPaint = Paint()
        ..color = _parseColor(color).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, glowPaint);
    }

    final paint = Paint()
      ..color = _parseColor(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return const Color(0xFF3b2f1e);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return strokes.length != oldDelegate.strokes.length ||
        currentStroke.length != oldDelegate.currentStroke.length ||
        eraserTrail.length != oldDelegate.eraserTrail.length ||
        eraserTrailOpacity != oldDelegate.eraserTrailOpacity;
  }
}
