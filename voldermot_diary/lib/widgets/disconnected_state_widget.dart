import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class DisconnectedStateWidget extends StatelessWidget {
  final String connectionStatus;
  final Color statusColor;
  final String serverMessage;
  final String serverUrl;
  final VoidCallback onReconnect;

  const DisconnectedStateWidget({
    super.key,
    required this.connectionStatus,
    required this.statusColor,
    required this.serverMessage,
    required this.serverUrl,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (connectionStatus == 'Connecting...')
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.15),
                  border: Border.all(color: statusColor, width: 3),
                ),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              )
            else
              // Lottie animation for disconnected/error states
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.width * 0.6,
                child: Lottie.asset(
                  'assets/animations/No Connection.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if animation fails to load
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withOpacity(0.15),
                        border: Border.all(color: statusColor, width: 3),
                      ),
                      child: Icon(
                        connectionStatus == 'Error'
                            ? Icons.error_outline
                            : Icons.wifi_off,
                        size: 40,
                        color: statusColor,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            Text(
              connectionStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              serverMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            // Reconnect button for disconnected/error states
            if (connectionStatus != 'Connecting...')
              ElevatedButton.icon(
                onPressed: onReconnect,
                icon: const Icon(Icons.link),
                label: const Text('Reconnect'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 24),
            // Server URL info
            Text(
              'Server: $serverUrl',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
