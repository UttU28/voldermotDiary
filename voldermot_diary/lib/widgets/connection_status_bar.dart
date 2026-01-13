import 'package:flutter/material.dart';

class ConnectionStatusBar extends StatelessWidget {
  final String connectionStatus;
  final Color statusColor;
  final int usersInRoom;

  const ConnectionStatusBar({
    super.key,
    required this.connectionStatus,
    required this.statusColor,
    required this.usersInRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.black.withOpacity(0.8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  connectionStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Text(
              'Users: $usersInRoom',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
