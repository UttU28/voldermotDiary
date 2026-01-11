class StrokePoint {
  final double x;
  final double y;
  final double pressure;
  final int timestamp;

  StrokePoint({
    required this.x,
    required this.y,
    required this.pressure,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'p': pressure,
        't': timestamp,
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        pressure: (json['p'] as num?)?.toDouble() ?? 0.5,
        timestamp: json['t'] as int,
      );
}

class Stroke {
  final String userId;
  final String roomId;
  final List<StrokePoint> points;
  final String color;
  final double width;
  final int createdAt;
  final String? socketId;

  Stroke({
    required this.userId,
    required this.roomId,
    required this.points,
    required this.color,
    required this.width,
    required this.createdAt,
    this.socketId,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'roomId': roomId,
        'points': points.map((p) => p.toJson()).toList(),
        'color': color,
        'width': width,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
        userId: json['userId'] as String,
        roomId: json['roomId'] as String,
        points: (json['points'] as List)
            .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        color: json['color'] as String? ?? '#3b2f1e',
        width: (json['width'] as num?)?.toDouble() ?? 3.0,
        createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        socketId: json['socketId'] as String?,
      );
}
