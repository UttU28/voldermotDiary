import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pages/loading_page.dart';
import 'widgets/disconnected_state_widget.dart';
import 'widgets/action_buttons_widget.dart';
import 'widgets/pages_list_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Voldermot's Diary",
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
  final IO.Socket? existingSocket;
  final String? existingSocketId;
  
  const ConnectionPage({
    super.key,
    this.existingSocket,
    this.existingSocketId,
  });

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
  final List<Function> socketListeners = [];
  
  // Pages list state
  List<Map<String, dynamic>> pages = [];
  bool isLoadingPages = false;
  String? pagesErrorMessage;

  // Get the correct server URL based on platform
  String get serverUrl {
    // Production URL (HTTPS)
    // const productionUrl = 'https://voldermotdiary.thatinsaneguy.com';
    const productionUrl = 'http://10.0.0.65:3012';
    
    // Local development URL (for testing)
    const localUrl = 'http://10.0.0.65:3000';
    
    // Use production URL by default, or local for development
    // Set USE_LOCAL_SERVER=true in environment to use local server
    const useLocal = const bool.fromEnvironment('USE_LOCAL_SERVER', defaultValue: false);
    
    return useLocal ? localUrl : productionUrl;
  }

  @override
  void initState() {
    super.initState();
    // If we have an existing socket, use it; otherwise connect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.existingSocket != null && widget.existingSocket!.connected) {
        // Reuse existing socket
        socket = widget.existingSocket;
        socketId = widget.existingSocketId ?? '';
        if (mounted) {
          setState(() {
            connectionStatus = 'Connected';
            statusColor = Colors.green;
            serverMessage = 'Connected to server';
            isConnecting = false;
          });
          setupSocketListeners();
          loadPages();
        }
      } else {
        // Connect to server
        connectToServer();
      }
    });
  }
  
  Future<void> loadPages() async {
    if (!mounted) return;
    setState(() {
      isLoadingPages = true;
      pagesErrorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('$serverUrl/api/pages'));
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            pages = List<Map<String, dynamic>>.from(data['pages'] ?? []);
            isLoadingPages = false;
          });
        } else {
          setState(() {
            pagesErrorMessage = data['error'] ?? 'Failed to load pages';
            isLoadingPages = false;
          });
        }
      } else {
        setState(() {
          pagesErrorMessage = 'Failed to load pages: ${response.statusCode}';
          isLoadingPages = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pagesErrorMessage = 'Error: $e';
        isLoadingPages = false;
      });
    }
  }

  Future<void> createNewPage() async {
    final now = DateTime.now();
    final pageName = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/pages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'pageName': pageName}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final page = data['page'];
          await loadPages();
          joinPage(page['pageId']);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create page: ${data['error']}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create page: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating page: $e')),
        );
      }
    }
  }

  Future<void> joinLatestPage() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/api/pages/latest'));
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['page'] != null) {
          joinPage(data['page']['pageId']);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No pages available. Create a new page first.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to get latest page: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting latest page: $e')),
        );
      }
    }
  }

  Future<void> deletePage(String pageId) async {
    try {
      final response = await http.delete(Uri.parse('$serverUrl/api/pages/$pageId'));
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Page deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
          // Refresh the pages list
          await loadPages();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete page: ${data['error']}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete page: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting page: $e')),
      );
    }
  }

  void joinPage(String pageId) {
    if (socket != null && socket!.connected) {
      final userId = socketId.isNotEmpty ? socketId : 'user-${DateTime.now().millisecondsSinceEpoch}';
      currentUserId = userId;
      socket!.emit('join-room', {
        'roomId': pageId,
        'userId': userId,
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected to server. Please reconnect.')),
        );
      }
    }
  }

  String formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void setupSocketListeners() {
    if (socket == null) return;
    
    // Clear existing listeners first
    for (var cleanup in socketListeners) {
      try {
        cleanup();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    socketListeners.clear();

    // Connection status event
    final connectionStatusHandler = (data) {
      if (mounted) {
        setState(() {
          socketId = data['socketId'] ?? socketId;
          serverMessage = data['message'] ?? 'Connected';
          if (connectionStatus != 'Connected') {
            connectionStatus = 'Connected';
            statusColor = Colors.green;
            isConnecting = false;
          }
        });
        // Load pages if not already loaded
        if (pages.isEmpty && !isLoadingPages) {
          loadPages();
        }
      }
      print('📡 Connection status: $data');
    };
    socket!.on('connection-status', connectionStatusHandler);
    socketListeners.add(() => socket?.off('connection-status', connectionStatusHandler));

    // Room joined event
    final roomJoinedHandler = (data) {
      if (mounted) {
        setState(() {
          usersInRoom = data['usersInRoom'] ?? 0;
          currentRoomId = data['roomId'] ?? 'default-room';
          currentUserId = data['userId'] ?? socketId;
          serverMessage = 'Joined room: ${data['roomId']}';
        });
        print('📝 Room joined: $data');
        
        // Navigate to loading page first, then to drawing page
        if (socket != null && socket!.connected && mounted) {
          Navigator.pushReplacement(
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
      }
    };
    socket!.on('room-joined', roomJoinedHandler);
    socketListeners.add(() => socket?.off('room-joined', roomJoinedHandler));

    // User joined event
    final userJoinedHandler = (data) {
      if (mounted) {
        setState(() {
          usersInRoom = data['usersInRoom'] ?? 0;
        });
      }
      print('👤 User joined: $data');
    };
    socket!.on('user-joined', userJoinedHandler);
    socketListeners.add(() => socket?.off('user-joined', userJoinedHandler));

    // User left event
    final userLeftHandler = (data) {
      if (mounted) {
        setState(() {
          usersInRoom = data['usersInRoom'] ?? 0;
        });
      }
      print('👋 User left: $data');
    };
    socket!.on('user-left', userLeftHandler);
    socketListeners.add(() => socket?.off('user-left', userLeftHandler));

    // Disconnect event
    socket!.onDisconnect((_) {
      if (mounted) {
        setState(() {
          connectionStatus = 'Disconnected';
          statusColor = Colors.red;
          serverMessage = 'Disconnected from server';
          socketId = '';
          usersInRoom = 0;
          isConnecting = false;
        });
      }
      print('❌ Disconnected from server');
    });

    // Error event
    socket!.onError((error) {
      if (mounted) {
    setState(() {
          connectionStatus = 'Error';
          statusColor = Colors.orange;
          serverMessage = 'Connection error: $error';
          isConnecting = false;
        });
      }
      print('⚠️ Error: $error');
    });
  }

  void connectToServer() {
    // Check if already connected
    if (socket != null && socket!.connected) {
      // Already connected, just load pages and update UI
      if (mounted) {
        setState(() {
          connectionStatus = 'Connected';
          statusColor = Colors.green;
          serverMessage = 'Connected to server';
          isConnecting = false;
        });
        loadPages();
      }
      return;
    }
    
    if (isConnecting) return; // Prevent multiple connection attempts
    
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
      statusColor = Colors.orange;
      serverMessage = 'Connecting to server...';
    });
    
    try {
      // Dispose old socket if exists
      if (socket != null) {
        socket!.dispose();
        socket = null;
      }
      
      socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .build(),
      );

      // Connection event
      socket!.onConnect((_) {
        if (mounted) {
          setState(() {
            connectionStatus = 'Connected';
            statusColor = Colors.green;
            serverMessage = 'Successfully connected to server';
            isConnecting = false;
          });
          setupSocketListeners();
          // Load pages when connected
          loadPages();
        }
        print('✅ Connected to server');
      });

      socket!.connect();
      
      // Add timeout for connection
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && isConnecting && (socket == null || !socket!.connected)) {
          setState(() {
            connectionStatus = 'Error';
            statusColor = Colors.red;
            serverMessage = 'Connection timeout. Please check if server is running.';
            isConnecting = false;
          });
          print('⏱️ Connection timeout');
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          connectionStatus = 'Error';
          statusColor = Colors.orange;
          serverMessage = 'Failed to connect: $e';
          isConnecting = false;
        });
      }
      print('❌ Connection error: $e');
    }
  }

  void disconnectFromServer() {
    // Remove all listeners first
    for (var cleanup in socketListeners) {
      try {
        cleanup();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    socketListeners.clear();
    
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    
    if (mounted) {
      setState(() {
        connectionStatus = 'Disconnected';
        statusColor = Colors.red;
        serverMessage = 'Disconnected';
        socketId = '';
        usersInRoom = 0;
      });
    }
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
    // Remove all socket listeners first to prevent setState after dispose
    for (var cleanup in socketListeners) {
      try {
        cleanup();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    socketListeners.clear();
    
    // Don't disconnect when navigating - socket is passed to HomePage
    // Only disconnect if explicitly disconnecting
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/icons/logo.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text("Voldermot's Diary"),
          ],
        ),
        actions: [
          if (connectionStatus == 'Connected') ...[
            // Refresh button with green dot indicator
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: loadPages,
                  tooltip: 'Refresh Pages',
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              onPressed: disconnectFromServer,
              tooltip: 'Disconnect',
            ),
          ] else if (connectionStatus == 'Disconnected' || connectionStatus == 'Error') ...[
            // Reconnect button with red dot indicator
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: connectToServer,
                  tooltip: 'Reconnect',
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: connectionStatus == 'Connected'
          ? SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Action buttons when connected
                    ActionButtonsWidget(
                      onCreateNewPage: createNewPage,
                      onJoinLatest: joinLatestPage,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Pages list (only show when connected)
                    PagesListWidget(
                      pages: pages,
                      isLoadingPages: isLoadingPages,
                      pagesErrorMessage: pagesErrorMessage,
                      onRefresh: loadPages,
                      onPageTap: joinPage,
                      onPageDelete: deletePage,
                      formatTimestamp: formatTimestamp,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Server URL and Room ID info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Server: $serverUrl',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        if (socketId.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '|',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            socketId,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey[400],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            )
          : DisconnectedStateWidget(
              connectionStatus: connectionStatus,
              statusColor: statusColor,
              serverMessage: serverMessage,
              serverUrl: serverUrl,
              onReconnect: connectToServer,
            ),
    );
  }
}
