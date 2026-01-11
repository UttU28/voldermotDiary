import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'pages/loading_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voldermot Diary',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.brown[300]!,
          secondary: Colors.amber[700]!,
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
          error: Colors.red[400]!,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown[700],
            foregroundColor: Colors.white,
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.brown),
          ),
        ),
        useMaterial3: true,
      ),
      home: const ConnectionPage(),
    );
  }
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  IO.Socket? socket;
  String connectionStatus = 'Connecting...';
  String socketId = '';
  String serverMessage = 'Connecting to server...';
  Color statusColor = Colors.orange;
  int usersInRoom = 0;
  String currentRoomId = '';
  String currentUserId = '';
  bool isConnecting = false;

  // Get the correct server URL based on platform
  String get serverUrl {
    if (kIsWeb) {
      // Web platform
      return 'http://10.0.0.65:3000';
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      // For physical Android device over WiFi, use your computer's local IP
      // For Android emulator, use 10.0.2.2 to access host machine's localhost
      // Change this to your computer's IP address when testing on physical device
      return 'http://10.0.0.65:3000';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      // For physical iOS device, use your computer's IP address
      return 'http://10.0.0.65:3000';
    } else {
      // Windows, Linux, macOS
      return 'http://10.0.0.65:3000';
      return 'http://localhost:3000';
    }
  }

  @override
  void initState() {
    super.initState();
    // Auto-connect on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectToServer();
    });
  }

  void connectToServer() {
    if (isConnecting) return; // Prevent multiple connection attempts
    
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
      statusColor = Colors.orange;
      serverMessage = 'Connecting to server...';
    });
    
    try {
      socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .build(),
      );

      // Connection event
      socket!.onConnect((_) {
        setState(() {
          connectionStatus = 'Connected';
          statusColor = Colors.green;
          serverMessage = 'Successfully connected to server';
          isConnecting = false;
        });
        print('✅ Connected to server');
      });

      // Connection status event
      socket!.on('connection-status', (data) {
        setState(() {
          socketId = data['socketId'] ?? '';
          serverMessage = data['message'] ?? 'Connected';
        });
        print('📡 Connection status: $data');
      });

      // Room joined event
      socket!.on('room-joined', (data) {
        setState(() {
          usersInRoom = data['usersInRoom'] ?? 0;
          currentRoomId = data['roomId'] ?? 'default-room';
          currentUserId = data['userId'] ?? socketId;
          serverMessage = 'Joined room: ${data['roomId']}';
        });
        print('📝 Room joined: $data');
        
        // Navigate to loading page first, then to drawing page
        if (socket != null && socket!.connected) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoadingPage(
                socket: socket!,
                socketId: socketId,
                roomId: currentRoomId,
                userId: currentUserId,
              ),
            ),
          );
        }
      });

      // User joined event
      socket!.on('user-joined', (data) {
        setState(() {
          usersInRoom = data['usersInRoom'] ?? 0;
        });
        print('👤 User joined: $data');
      });

      // User left event
      socket!.on('user-left', (data) {
        setState(() {
          usersInRoom = data['usersInRoom'] ?? 0;
        });
        print('👋 User left: $data');
      });

      // Disconnect event
      socket!.onDisconnect((_) {
        setState(() {
          connectionStatus = 'Disconnected';
          statusColor = Colors.red;
          serverMessage = 'Disconnected from server';
          socketId = '';
          usersInRoom = 0;
          isConnecting = false;
        });
        print('❌ Disconnected from server');
      });

      // Error event
      socket!.onError((error) {
        setState(() {
          connectionStatus = 'Error';
          statusColor = Colors.orange;
          serverMessage = 'Connection error: $error';
          isConnecting = false;
        });
        print('⚠️ Error: $error');
      });

      socket!.connect();
    } catch (e) {
      setState(() {
        connectionStatus = 'Error';
        statusColor = Colors.orange;
        serverMessage = 'Failed to connect: $e';
        isConnecting = false;
      });
      print('❌ Connection error: $e');
    }
  }

  void disconnectFromServer() {
    socket?.disconnect();
    socket?.dispose();
    setState(() {
      connectionStatus = 'Disconnected';
      statusColor = Colors.red;
      serverMessage = 'Disconnected';
      socketId = '';
      usersInRoom = 0;
    });
  }

  void joinRoom() {
    if (socket != null && socket!.connected) {
      final userId = socketId.isNotEmpty ? socketId : 'user-${DateTime.now().millisecondsSinceEpoch}';
      currentUserId = userId;
      socket!.emit('join-room', {
        'roomId': 'default-room',
        'userId': userId,
      });
    }
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🪄 Voldermot Diary'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status indicator
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.2),
                  border: Border.all(color: statusColor, width: 3),
                ),
                child: connectionStatus == 'Connecting...'
                    ? const SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      )
                    : Icon(
                        connectionStatus == 'Connected'
                            ? Icons.check_circle
                            : connectionStatus == 'Error'
                                ? Icons.error
                                : Icons.cancel,
                        size: 60,
                        color: statusColor,
                      ),
              ),
              const SizedBox(height: 24),
              
              // Connection status text
              Text(
                connectionStatus,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 16),
              
              // Server message
              Text(
                serverMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              // Socket ID
              if (socketId.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        const Text('Socket ID:', style: TextStyle(fontSize: 12)),
                        Text(
                          socketId,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Users in room
              if (usersInRoom > 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Users in room: $usersInRoom',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Connect button (show if disconnected or error - for manual retry)
              if (connectionStatus == 'Disconnected' || connectionStatus == 'Error')
                ElevatedButton.icon(
                  onPressed: connectToServer,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect to Server'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              
              // Disconnect button
              if (connectionStatus == 'Connected')
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: joinRoom,
                      icon: const Icon(Icons.group_add),
                      label: const Text('Join Room'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: disconnectFromServer,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Disconnect'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 24),
              
              // Server URL info
              Text(
                'Server: $serverUrl',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
