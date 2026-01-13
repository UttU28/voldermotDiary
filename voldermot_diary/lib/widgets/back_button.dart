import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../main.dart';

class DrawingBackButton extends StatelessWidget {
  final IO.Socket socket;
  final String socketId;
  final String userId;
  final String roomId;
  
  static const String _backArrowLottie = 'https://lottie.host/embed/8c5b5e5e-3f4a-4c8b-9f2d-1e3f4a5b6c7d/8c5b5e5e.json';

  const DrawingBackButton({
    super.key,
    required this.socket,
    required this.socketId,
    required this.userId,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 48,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[700]!.withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Leave the room before navigating back
              if (socket.connected) {
                socket.emit('leave-room', {
                  'roomId': roomId,
                  'userId': userId,
                });
              }
              
              // Navigate back to ConnectionPage (main home screen) with existing socket
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => ConnectionPage(
                    existingSocket: socket,
                    existingSocketId: socketId,
                  ),
                ),
                (route) => false, // Remove all previous routes
              );
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Opacity(
                opacity: 0.7,
                child: Lottie.network(
                  _backArrowLottie,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.arrow_back, color: Colors.white, size: 24);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
