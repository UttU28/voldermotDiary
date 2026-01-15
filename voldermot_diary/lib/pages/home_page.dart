import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'loading_page.dart';

class HomePage extends StatefulWidget {
  final IO.Socket socket;
  final String socketId;
  final String userId;

  const HomePage({
    super.key,
    required this.socket,
    required this.socketId,
    required this.userId,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> pages = [];
  bool isLoading = true;
  String? errorMessage;

  String get serverUrl {
    if (kIsWeb) {
      return 'http://10.0.0.65:3000';
    } else if (Platform.isAndroid || Platform.isIOS) {
      return 'http://10.0.0.65:3000';
    } else {
      return 'http://10.0.0.65:3000';
    }
  }

  @override
  void initState() {
    super.initState();
    loadPages();
    setupSocketListeners();
  }

  void setupSocketListeners() {
    widget.socket.on('room-joined', (data) {
      if (mounted) {
        final roomId = data['roomId'] ?? 'default-room';
        final userId = data['userId'] ?? widget.userId;
        print('📝 HomePage: Room joined - roomId: $roomId, userId: $userId');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoadingPage(
              socket: widget.socket,
              socketId: widget.socketId,
              roomId: roomId,
              userId: userId,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    widget.socket.off('room-joined');
    super.dispose();
  }

  Future<void> loadPages() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('$serverUrl/api/pages'));
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            pages = List<Map<String, dynamic>>.from(data['pages'] ?? []);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['error'] ?? 'Failed to load pages';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load pages: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
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
          // Refresh pages list
          await loadPages();
          // Join the newly created page
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

  void joinPage(String pageId) {
    print('📤 HomePage: Attempting to join page - pageId: $pageId, userId: ${widget.userId}');
    print('📤 HomePage: Socket connected: ${widget.socket.connected}');
    
    if (widget.socket.connected) {
      widget.socket.emit('join-room', {
        'roomId': pageId,
        'userId': widget.userId,
      });
    } else {
      // Try to reconnect
      if (!widget.socket.connected) {
        widget.socket.connect();
        // Wait a bit for connection, then try again
        Future.delayed(const Duration(milliseconds: 500), () {
          if (widget.socket.connected && mounted) {
            widget.socket.emit('join-room', {
              'roomId': pageId,
              'userId': widget.userId,
            });
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Not connected to server. Please reconnect.')),
            );
          }
        });
      } else if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.socket.connected;
    
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadPages,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          if (!isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withOpacity(0.8),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Not connected to server. Please reconnect.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.socket.connect();
                    },
                    child: const Text('Reconnect', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadPages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: createNewPage,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Page'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: joinLatestPage,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Join Latest'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: pages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pages yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a new page to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: pages.length,
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber[700],
                          child: const Icon(Icons.description, color: Colors.white),
                        ),
                        title: Text(
                          page['pageName'] ?? 'Untitled Page',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Created: ${formatTimestamp(page['createdAt'] ?? 0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              'Last active: ${formatTimestamp(page['lastActivity'] ?? 0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => joinPage(page['pageId']),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
