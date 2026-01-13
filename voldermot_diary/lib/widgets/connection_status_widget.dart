import 'package:flutter/material.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final String connectionStatus;
  final Color statusColor;
  final String socketId;

  const ConnectionStatusWidget({
    super.key,
    required this.connectionStatus,
    required this.statusColor,
    required this.socketId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor.withOpacity(0.2),
            border: Border.all(color: statusColor, width: 2),
          ),
          child: Icon(
            Icons.check_circle,
            size: 18,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                connectionStatus,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              if (socketId.isNotEmpty)
                Text(
                  socketId,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.grey[400],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
