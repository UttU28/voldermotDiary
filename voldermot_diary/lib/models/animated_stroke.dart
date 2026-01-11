import 'stroke.dart';

class AnimatedStroke {
  final Stroke stroke;
  double animationProgress; // Mutable for animation
  final bool isFromOtherUser;

  AnimatedStroke({
    required this.stroke,
    this.animationProgress = 0.0,
    this.isFromOtherUser = false,
  });

  int get visiblePointsCount {
    // If animation is complete (1.0) or it's not from another user, show all points
    if (animationProgress >= 1.0 || !isFromOtherUser) {
      return stroke.points.length;
    }
    // Otherwise, show points based on animation progress
    return (stroke.points.length * animationProgress).floor();
  }

  List<StrokePoint> get visiblePoints {
    // If animation is complete or it's the user's own stroke, show all points
    if (animationProgress >= 1.0 || !isFromOtherUser) {
      return stroke.points;
    }
    // Otherwise, show partial points based on animation
    final count = visiblePointsCount.clamp(0, stroke.points.length);
    return stroke.points.sublist(0, count);
  }

  bool get isComplete => animationProgress >= 1.0 || !isFromOtherUser;
}
