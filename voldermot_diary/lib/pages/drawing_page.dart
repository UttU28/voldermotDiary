import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/stroke.dart';
import '../models/animated_stroke.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/back_button.dart' show DrawingBackButton;
import '../widgets/control_buttons.dart';
import '../main.dart';
import '../widgets/drawing_painter.dart';

class DrawingPage extends StatefulWidget {
  final IO.Socket socket;
  final String socketId;
  final String roomId;
  final String userId;

  const DrawingPage({
    super.key,
    required this.socket,
    required this.socketId,
    required this.roomId,
    required this.userId,
  });

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> with TickerProviderStateMixin {
  final List<AnimatedStroke> strokes = [];
  final List<StrokePoint> currentStroke = [];
  final List<Offset> eraserTrail = []; // Track eraser path for trail
  final Map<String, AnimationController> strokeAnimations = {};
  AnimationController? _eraserTrailFadeController;
  bool isDrawing = false;
  bool isErasing = false; // Track if currently erasing
  String connectionStatus = 'Connected';
  Color statusColor = Colors.green;
  int usersInRoom = 1;
  
  // Track deleted strokes during current eraser drag to prevent duplicate deletions
  // Limited to last 1000 deletions to prevent memory leaks
  final Set<String> _deletedStrokeIds = {};
  static const int _maxDeletedStrokeIds = 1000;
  
  // Track if we're refreshing strokes due to erase (skip animation in this case)
  bool _isEraseRefresh = false;
  
  // Debounce timer for requesting strokes to reduce server load
  Timer? _requestStrokesDebounceTimer;
  
  // Canvas dimensions for coordinate normalization
  Size? canvasSize;

  // Drawing settings
  String strokeColor = '#FFEB3B'; // Default: Yellow
  final double strokeWidth = 4.0;
  final double animationDuration = 0.5;
  
  // Color options for pen
  final List<Map<String, dynamic>> colorOptions = [
    {'name': 'Yellow', 'color': '#FFEB3B', 'displayColor': Colors.yellow},
    {'name': 'Green', 'color': '#4CAF50', 'displayColor': Colors.green},
    {'name': 'Red', 'color': '#F44336', 'displayColor': Colors.red},
    {'name': 'Blue', 'color': '#2196F3', 'displayColor': Colors.blue},
  ];
  
  // Store socket listeners for cleanup
  final List<Function> socketListeners = [];
  
  // Tool selection: 'pen' or 'eraser'
  String selectedTool = 'pen';
  
  // Palm rejection: when true, only stylus/Apple Pencil works (finger rejected)
  // when false, finger and stylus both work
  bool palmRejectionEnabled = false; // Default: finger allowed
  
  // Controls visibility
  bool _controlsVisible = true;
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  
  late AnimationController _colorPickerAnimationController;
  late Animation<double> _colorPickerAnimation;

  // Global key for capturing canvas screenshot
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    setupSocketListeners();
    
    // Request existing strokes after a short delay to ensure listeners are ready
    // This is initial page load, so animation should play
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _isEraseRefresh = false; // Ensure animation plays on initial load
        widget.socket.emit('request-strokes', {
          'roomId': widget.roomId,
        });
      }
    });
    
    // Initialize controls animation controller
    _controlsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    // Use easeOutCubic for smooth animation without bounce
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeOutCubic,
    );
    
    // Initialize color picker animation controller
    _colorPickerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _colorPickerAnimation = CurvedAnimation(
      parent: _colorPickerAnimationController,
      curve: Curves.easeInOutCubic,
    );
    
    // Start with controls visible
    _controlsAnimationController.value = 1.0;
    
    // Initialize eraser trail fade controller
    _eraserTrailFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  // Animate a single stroke (for real-time strokes from other users)
  void _animateStroke(String strokeId, AnimatedStroke animatedStroke) {
    if (!mounted) return;
    
    final pointCount = animatedStroke.stroke.points.length;
    final baseDuration = 300;
    final perPointDuration = 5;
    final totalDuration = baseDuration + (pointCount * perPointDuration);
    
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDuration.clamp(300, 2000)),
    );
    
    strokeAnimations[strokeId] = controller;
    
    controller.addListener(() {
      if (mounted) {
        setState(() {
          animatedStroke.animationProgress = controller.value;
        });
      }
    });
    
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && strokeAnimations.containsKey(strokeId)) {
            controller.dispose();
            strokeAnimations.remove(strokeId);
          }
        });
      }
    });
    
    if (mounted) {
      controller.forward();
    } else {
      controller.dispose();
    }
  }

  // Animate all loaded strokes together in 1 second
  void _animateLoadedStrokes(List<AnimatedStroke> strokesToAnimate) {
    if (!mounted) return;
    
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    final animationId = 'loaded_${DateTime.now().millisecondsSinceEpoch}';
    strokeAnimations[animationId] = controller;
    
    controller.addListener(() {
      if (mounted) {
        setState(() {
          for (var stroke in strokesToAnimate) {
            stroke.animationProgress = controller.value;
          }
        });
      }
    });
    
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && strokeAnimations.containsKey(animationId)) {
            controller.dispose();
            strokeAnimations.remove(animationId);
          }
        });
      }
    });
    
    if (mounted) {
      controller.forward();
    } else {
      controller.dispose();
    }
  }

  void setupSocketListeners() {
    // Listen for existing strokes when joining room (from database)
    final loadStrokesHandler = (data) {
      if (!mounted) return;
      
      final receivedRoomId = data['roomId'] as String?;
      
      // Only process strokes for the current room
      if (receivedRoomId != null && receivedRoomId != widget.roomId) {
        print('⚠️ Ignoring load-strokes from different room: $receivedRoomId (current: ${widget.roomId})');
        return;
      }
      
      print('📥 Received load-strokes event for room: ${widget.roomId} with data: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}');
      
      try {
        final strokesList = data['strokes'] as List?;
        print('📊 Parsed strokes list: ${strokesList?.length ?? 0} strokes');
        
        if (strokesList == null || strokesList.isEmpty) {
          print('ℹ️ No strokes to load');
          if (mounted) {
            setState(() {
              strokes.clear();
            });
          }
          return;
        }
        
        final loadedStrokes = <AnimatedStroke>[];
        
        for (var strokeData in strokesList) {
          try {
            // Parse points from database - points are already parsed JSON from database
            List<StrokePoint> points = [];
            if (strokeData['points'] is List) {
              final pointsList = strokeData['points'] as List;
              for (var p in pointsList) {
                if (p is Map) {
                  points.add(StrokePoint(
                    x: (p['x'] as num).toDouble(),
                    y: (p['y'] as num).toDouble(),
                    pressure: (p['p'] as num?)?.toDouble() ?? 0.5,
                    timestamp: (p['t'] as num?)?.toInt() ?? 0,
                  ));
                }
              }
            }
            
            if (points.isEmpty) {
              print('⚠️ Skipping stroke with no points');
              continue;
            }
            
            final stroke = Stroke(
              userId: strokeData['userId']?.toString() ?? 'unknown',
              roomId: strokeData['roomId']?.toString() ?? widget.roomId,
              points: points,
              color: strokeData['color']?.toString() ?? '#8B6914',
              width: (strokeData['width'] as num?)?.toDouble() ?? 4.0,
              createdAt: (strokeData['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
              socketId: strokeData['socketId']?.toString(),
            );
            
            print('✅ Loaded stroke: ${stroke.points.length} points, userId: ${stroke.userId}');
            
            // Start with 0 progress for animation
            loadedStrokes.add(AnimatedStroke(
              stroke: stroke,
              animationProgress: 0.0,
              isFromOtherUser: stroke.userId != widget.userId,
            ));
          } catch (e) {
            print('❌ Error parsing stroke: $e');
            // Skip invalid strokes
          }
        }
        
        if (!mounted) return;
        
        print('🎨 Adding ${loadedStrokes.length} strokes to canvas');
        
        // When loading fresh strokes from database, clear deleted stroke tracking
        // Database is the source of truth - if a stroke is in the DB, it should be shown
        // Clear the tracking set to prevent memory leaks and ensure fresh state
        setState(() {
          strokes.clear();
          // If this is an erase refresh, set animation progress to 1.0 (fully visible, no animation)
          // Otherwise, start with 0.0 for animation
          for (var stroke in loadedStrokes) {
            if (_isEraseRefresh) {
              stroke.animationProgress = 1.0; // Skip animation during erase refresh
            }
          }
          strokes.addAll(loadedStrokes);
          // Clear deleted stroke IDs when loading fresh strokes from database
          // Database is source of truth - if stroke is deleted from DB, it won't be in this list
          _deletedStrokeIds.clear();
        });
        
        // Only animate if this is NOT an erase refresh (initial page load or normal refresh)
        final shouldAnimate = !_isEraseRefresh;
        
        // Reset the flag after checking
        if (_isEraseRefresh) {
          print('⏭️ Skipping animation during erase refresh');
          _isEraseRefresh = false;
        }
        
        if (loadedStrokes.isNotEmpty && mounted && shouldAnimate) {
          print('🎬 Starting animation for ${loadedStrokes.length} strokes');
          _animateLoadedStrokes(loadedStrokes);
        }
      } catch (e) {
        print('❌ Error loading strokes: $e');
      }
    };
    
    widget.socket.on('load-strokes', loadStrokesHandler);
    socketListeners.add(() => widget.socket.off('load-strokes', loadStrokesHandler));

    // Listen for strokes from other users
    final strokeHandler = (data) {
      if (!mounted) return;
      
      try {
        final stroke = Stroke.fromJson(data);
        
        // Only process strokes for the current room
        if (stroke.roomId != widget.roomId) {
          print('⚠️ Ignoring stroke from different room: ${stroke.roomId} (current: ${widget.roomId})');
          return;
        }
        
        final strokeId = '${stroke.userId}_${stroke.createdAt}';
        
        // Skip if this stroke was deleted (shouldn't happen, but safety check)
        if (_deletedStrokeIds.contains(strokeId)) {
          print('⚠️ Ignoring stroke that was deleted: $strokeId');
          return;
        }
        
        // Skip own strokes (they're already added locally)
        if (stroke.userId == widget.userId || stroke.socketId == widget.socketId) {
          return;
        }
        
        // Check if stroke already exists (prevent duplicates)
        final alreadyExists = strokes.any((s) => 
          s.stroke.userId == stroke.userId && 
          s.stroke.createdAt == stroke.createdAt
        );
        
        if (alreadyExists) {
          print('⚠️ Ignoring duplicate stroke: $strokeId');
          return;
        }
        
        final animatedStroke = AnimatedStroke(
          stroke: stroke,
          animationProgress: 0.0,
          isFromOtherUser: true,
        );
        
        if (mounted) {
          setState(() {
            strokes.add(animatedStroke);
          });
          _animateStroke(strokeId, animatedStroke);
        }
      } catch (e) {
        // Error handled silently
      }
    };
    
    widget.socket.on('stroke', strokeHandler);
    socketListeners.add(() => widget.socket.off('stroke', strokeHandler));

    // Listen for canvas clear event
    final clearHandler = (data) {
      if (!mounted) return;
      
      final clearedRoomId = data['roomId'] as String?;
      // Only process clear events for the current room
      if (clearedRoomId != null && clearedRoomId != widget.roomId) {
        return;
      }
      
      setState(() {
        strokes.clear();
        currentStroke.clear();
        _deletedStrokeIds.clear(); // Clear deleted stroke tracking when canvas is cleared
      });
    };
    
    widget.socket.on('canvas-cleared', clearHandler);
    socketListeners.add(() => widget.socket.off('canvas-cleared', clearHandler));

    // Listen for connection status
    final statusHandler = (data) {
      if (!mounted) return;
      final status = (data['status'] ?? 'connected').toString().toLowerCase();
      setState(() {
        connectionStatus = status;
        // Map status to color: 'connected' -> green, 'disconnected'/'error' -> red, else -> orange
        if (status == 'connected') {
          statusColor = Colors.green;
          connectionStatus = 'Connected'; // Normalize for display
        } else if (status == 'disconnected' || status == 'error') {
          statusColor = Colors.red;
          connectionStatus = status == 'disconnected' ? 'Disconnected' : 'Error';
        } else {
          statusColor = Colors.orange;
          connectionStatus = 'Connecting...';
        }
      });
    };
    
    widget.socket.on('connection-status', statusHandler);
    socketListeners.add(() => widget.socket.off('connection-status', statusHandler));

    // Listen for room-joined event (happens when joining or rejoining a room)
    final roomJoinedHandler = (data) {
      if (!mounted) return;
      final joinedRoomId = data['roomId'] as String?;
      
      // Only process if it's our room
      if (joinedRoomId != null && joinedRoomId == widget.roomId) {
        print('🔄 Room joined/rejoined: $joinedRoomId');
        setState(() {
          usersInRoom = data['usersInRoom'] ?? usersInRoom;
        });
        
        // Request fresh strokes after room join completes
        // Backend sends automatically after 3.5s, but also request immediately
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _isEraseRefresh = false; // Allow animation on rejoin
            widget.socket.emit('request-strokes', {
              'roomId': widget.roomId,
            });
          }
        });
      }
    };
    
    widget.socket.on('room-joined', roomJoinedHandler);
    socketListeners.add(() => widget.socket.off('room-joined', roomJoinedHandler));

    // Listen for user joined/left
    final userJoinedHandler = (data) {
      if (!mounted) return;
      setState(() {
        usersInRoom = data['usersInRoom'] ?? usersInRoom;
      });
    };
    
    widget.socket.on('user-joined', userJoinedHandler);
    socketListeners.add(() => widget.socket.off('user-joined', userJoinedHandler));

    final userLeftHandler = (data) {
      if (!mounted) return;
      setState(() {
        usersInRoom = data['usersInRoom'] ?? usersInRoom;
      });
    };
    
    widget.socket.on('user-left', userLeftHandler);
    socketListeners.add(() => widget.socket.off('user-left', userLeftHandler));

    // Listen for stroke deletion
    final strokeDeletedHandler = (data) {
      if (!mounted) return;
      
      final deletedRoomId = data['roomId'] as String?;
      // Only process delete events for the current room
      if (deletedRoomId != null && deletedRoomId != widget.roomId) {
        return;
      }
      
      final userId = data['userId'] as String?;
      final createdAt = data['createdAt'] as int?;
      
      if (userId != null && createdAt != null) {
        final strokeId = '${userId}_${createdAt}';
        
        // Mark as deleted to prevent re-adding
        _deletedStrokeIds.add(strokeId);
        
        // Prevent memory leak by limiting set size
        if (_deletedStrokeIds.length > _maxDeletedStrokeIds) {
          final idsList = _deletedStrokeIds.toList();
          idsList.removeRange(0, idsList.length - _maxDeletedStrokeIds ~/ 2);
          _deletedStrokeIds.clear();
          _deletedStrokeIds.addAll(idsList);
        }
        
        // Remove from local state immediately
        setState(() {
          strokes.removeWhere((s) => 
            s.stroke.userId == userId && 
            s.stroke.createdAt == createdAt
          );
        });
        
        // Debounce stroke refresh requests to reduce server load
        // Cancel any pending request and schedule a new one
        _requestStrokesDebounceTimer?.cancel();
        _requestStrokesDebounceTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) {
            _isEraseRefresh = true; // Mark as erase refresh to skip animation
            widget.socket.emit('request-strokes', {
              'roomId': widget.roomId,
            });
          }
        });
      }
    };
    
    widget.socket.on('stroke-deleted', strokeDeletedHandler);
    socketListeners.add(() => widget.socket.off('stroke-deleted', strokeDeletedHandler));

    // Listen for disconnect
    widget.socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() {
        connectionStatus = 'Disconnected';
        statusColor = Colors.red;
      });
    });
    
    // Listen for reconnect - rejoin room and fetch fresh data
    widget.socket.onConnect((_) {
      if (!mounted) return;
      print('🔄 Reconnected to server, rejoining room and fetching data');
      setState(() {
        connectionStatus = 'Connected';
        statusColor = Colors.green;
      });
      
      // Clear any stale data
      _deletedStrokeIds.clear();
      
      // Rejoin the room
      widget.socket.emit('join-room', {
        'roomId': widget.roomId,
        'userId': widget.userId,
      });
      
      // Request fresh strokes multiple times to ensure we get the latest data
      // First request immediately
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _isEraseRefresh = false; // Allow animation on reconnection
          widget.socket.emit('request-strokes', {
            'roomId': widget.roomId,
          });
        }
      });
      
      // Second request after room join completes (backend sends after 3.5s, so request at 4s)
      Future.delayed(const Duration(milliseconds: 4000), () {
        if (mounted) {
          _isEraseRefresh = false;
          widget.socket.emit('request-strokes', {
            'roomId': widget.roomId,
          });
        }
      });
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (canvasSize == null) return;
    
    // Palm rejection: if enabled, reject finger touches, only allow stylus
    if (palmRejectionEnabled && event.kind != PointerDeviceKind.stylus) {
      return; // Reject finger/mouse touches
    }
    
    // Clear eraser trail if switching from eraser to pen
    if (selectedTool == 'pen' && eraserTrail.isNotEmpty) {
      _clearEraserTrail();
    }
    
    // If eraser is selected, start erasing
    if (selectedTool == 'eraser') {
      setState(() {
        isErasing = true;
        eraserTrail.clear();
        eraserTrail.add(event.localPosition);
        _eraserTrailFadeController?.stop();
        _eraserTrailFadeController?.reset();
        // Don't clear deleted stroke IDs - keep them to prevent re-adding deleted strokes
      });
      _handleEraserDrag(event.localPosition);
      return;
    }
    
    // Pen mode - start drawing
    setState(() {
      isDrawing = true;
      currentStroke.clear();
      final point = event.localPosition;
      final normalizedX = point.dx / canvasSize!.width;
      final normalizedY = point.dy / canvasSize!.height;
      // Use pressure from stylus if available, otherwise default
      final pressure = event.pressure > 0 ? event.pressure : 0.7;
      currentStroke.add(StrokePoint(
        x: normalizedX,
        y: normalizedY,
        pressure: pressure,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    });
  }

  void onPanStart(DragStartDetails details) {
    if (canvasSize == null) return;
    
    // Clear eraser trail if switching from eraser to pen
    if (selectedTool == 'pen' && eraserTrail.isNotEmpty) {
      _clearEraserTrail();
    }
    
    // If eraser is selected, start erasing
    if (selectedTool == 'eraser') {
      setState(() {
        isErasing = true;
        eraserTrail.clear();
        eraserTrail.add(details.localPosition);
        _eraserTrailFadeController?.stop();
        _eraserTrailFadeController?.reset();
        // Don't clear deleted stroke IDs - keep them to prevent re-adding deleted strokes
      });
      _handleEraserDrag(details.localPosition);
      return;
    }
    
    // Pen mode - start drawing
    setState(() {
      isDrawing = true;
      currentStroke.clear();
      final point = details.localPosition;
      final normalizedX = point.dx / canvasSize!.width;
      final normalizedY = point.dy / canvasSize!.height;
      currentStroke.add(StrokePoint(
        x: normalizedX,
        y: normalizedY,
        pressure: 0.7,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    });
  }
  
  void _clearEraserTrail() {
    if (!mounted) return;
    setState(() {
      isErasing = false;
      eraserTrail.clear();
      _eraserTrailFadeController?.stop();
      _eraserTrailFadeController?.reset();
    });
  }
  
  void _handleEraserDrag(Offset dragPosition) {
    if (canvasSize == null || !mounted) return;
    
    // Add to eraser trail
    setState(() {
      eraserTrail.add(dragPosition);
      // Keep trail limited to last 20 points for performance
      if (eraserTrail.length > 20) {
        eraserTrail.removeAt(0);
      }
    });
    
    final normalizedX = dragPosition.dx / canvasSize!.width;
    final normalizedY = dragPosition.dy / canvasSize!.height;
    const eraserRadius = 0.04; // 4% of screen size for eraser contact area
    
    // Find all strokes that come in contact with the eraser position
    final List<AnimatedStroke> strokesToDelete = [];
    
    // Check each stroke's points to see if any are within eraser radius
    // Use a copy of the strokes list to avoid modification during iteration
    final strokesCopy = List<AnimatedStroke>.from(strokes);
    for (var animatedStroke in strokesCopy) {
      // Skip if this stroke was already deleted
      final strokeId = '${animatedStroke.stroke.userId}_${animatedStroke.stroke.createdAt}';
      if (_deletedStrokeIds.contains(strokeId)) {
        continue;
      }
      
      for (var point in animatedStroke.stroke.points) {
        final dx = point.x - normalizedX;
        final dy = point.y - normalizedY;
        final distance = dx * dx + dy * dy;
        
        // If any point of the stroke is within eraser radius, mark for deletion
        if (distance < (eraserRadius * eraserRadius)) {
          strokesToDelete.add(animatedStroke);
          break; // No need to check other points of this stroke
        }
      }
    }
    
    // Delete all strokes that came in contact
    for (var animatedStroke in strokesToDelete) {
      _deleteStroke(animatedStroke.stroke);
    }
  }
  
  void _deleteStroke(Stroke stroke) {
    if (!mounted) return;
    
    final strokeId = '${stroke.userId}_${stroke.createdAt}';
    
    // Skip if already deleted
    if (_deletedStrokeIds.contains(strokeId)) {
      return;
    }
    
    // Mark as deleted
    _deletedStrokeIds.add(strokeId);
    
    // Prevent memory leak by limiting set size
    if (_deletedStrokeIds.length > _maxDeletedStrokeIds) {
      // Remove oldest entries (convert to list, remove first, recreate set)
      final idsList = _deletedStrokeIds.toList();
      idsList.removeRange(0, idsList.length - _maxDeletedStrokeIds ~/ 2);
      _deletedStrokeIds.clear();
      _deletedStrokeIds.addAll(idsList);
    }
    
    // Remove from local state immediately
    setState(() {
      strokes.removeWhere((s) => 
        s.stroke.createdAt == stroke.createdAt && 
        s.stroke.userId == stroke.userId
      );
    });
    
    // Send delete request to server
    widget.socket.emit('delete-stroke', {
      'roomId': widget.roomId,
      'strokeId': strokeId,
      'userId': stroke.userId,
      'createdAt': stroke.createdAt,
    });
    
    // Debounce stroke refresh requests to reduce server load
    // Cancel any pending request and schedule a new one
    _requestStrokesDebounceTimer?.cancel();
    _requestStrokesDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _isEraseRefresh = true; // Mark as erase refresh to skip animation
        widget.socket.emit('request-strokes', {
          'roomId': widget.roomId,
        });
      }
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (canvasSize == null) return;
    
    // Palm rejection: if enabled, reject finger touches
    if (palmRejectionEnabled && event.kind != PointerDeviceKind.stylus) {
      return;
    }
    
    // If eraser is selected, handle erasing during drag
    if (selectedTool == 'eraser') {
      _handleEraserDrag(event.localPosition);
      return;
    }
    
    // Pen mode - continue drawing
    if (!isDrawing) return;

    setState(() {
      final point = event.localPosition;
      // Normalize coordinates to 0.0-1.0 range
      final normalizedX = point.dx / canvasSize!.width;
      final normalizedY = point.dy / canvasSize!.height;
      // Use pressure from stylus if available, otherwise slight variation
      final pressure = event.pressure > 0 
          ? event.pressure 
          : 0.6 + (DateTime.now().millisecond % 100) / 500;
      currentStroke.add(StrokePoint(
        x: normalizedX,
        y: normalizedY,
        pressure: pressure,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    });
  }

  void onPanUpdate(DragUpdateDetails details) {
    if (canvasSize == null) return;
    
    // If eraser is selected, handle erasing during drag
    if (selectedTool == 'eraser') {
      _handleEraserDrag(details.localPosition);
      return;
    }
    
    // Pen mode - continue drawing
    if (!isDrawing) return;

    setState(() {
      final point = details.localPosition;
      // Normalize coordinates to 0.0-1.0 range
      final normalizedX = point.dx / canvasSize!.width;
      final normalizedY = point.dy / canvasSize!.height;
      // Add point with slight pressure variation for natural feel
      currentStroke.add(StrokePoint(
        x: normalizedX,
        y: normalizedY,
        pressure: 0.6 + (DateTime.now().millisecond % 100) / 500, // 0.6-0.8 range
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    // Palm rejection: if enabled, reject finger touches
    if (palmRejectionEnabled && event.kind != PointerDeviceKind.stylus) {
      isDrawing = false;
      currentStroke.clear();
      return;
    }
    
    // Immediately clear eraser trail when drag ends
    if (selectedTool == 'eraser') {
      _clearEraserTrail();
      // Keep deleted stroke IDs tracked (don't clear here - only clear when starting new drag)
      return;
    }
    
    if (!isDrawing || currentStroke.isEmpty) return;

    // Create stroke from current points
    final strokePoints = List<StrokePoint>.from(currentStroke);
    
    // Create stroke
    final stroke = Stroke(
      userId: widget.userId,
      roomId: widget.roomId,
      points: strokePoints,
      color: strokeColor,
      width: strokeWidth,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Add to local strokes (not animated for own strokes)
    setState(() {
      strokes.add(AnimatedStroke(
        stroke: stroke,
        isFromOtherUser: false,
      ));
      isDrawing = false;
      currentStroke.clear();
    });

    // Send to backend
    widget.socket.emit('stroke', stroke.toJson());
  }

  void onPanEnd(DragEndDetails details) {
    // Immediately clear eraser trail when drag ends
    if (selectedTool == 'eraser') {
      _clearEraserTrail();
      // Keep deleted stroke IDs tracked (don't clear here - only clear when starting new drag)
      return;
    }
    
    if (!isDrawing || currentStroke.isEmpty) return;

    // Create stroke from current points
    final strokePoints = List<StrokePoint>.from(currentStroke);
    
    // Create stroke
    final stroke = Stroke(
      userId: widget.userId,
      roomId: widget.roomId,
      points: strokePoints,
      color: strokeColor,
      width: strokeWidth,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Add to local strokes (not animated for own strokes)
    setState(() {
      strokes.add(AnimatedStroke(
        stroke: stroke,
        isFromOtherUser: false,
      ));
      isDrawing = false;
      currentStroke.clear();
    });

    // Send to backend
    widget.socket.emit('stroke', stroke.toJson());
  }

  void clearCanvas() {
    // Send clear request to server (will clear DB and notify all clients)
    widget.socket.emit('clear-canvas', {
      'roomId': widget.roomId,
    });
    
    // Clear local strokes immediately
    setState(() {
      strokes.clear();
      currentStroke.clear();
      _deletedStrokeIds.clear(); // Clear deleted stroke tracking when canvas is cleared
    });
    
    // Request fresh strokes from database after clearing to ensure sync
    // Don't mark as erase refresh - clearing canvas should show animation on reload
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.socket.emit('request-strokes', {
          'roomId': widget.roomId,
        });
      }
    });
  }
  
  // Force refresh strokes from database
  void _refreshStrokesFromDatabase() {
    if (!mounted) return;
    _isEraseRefresh = false; // Allow animation on manual refresh
    widget.socket.emit('request-strokes', {
      'roomId': widget.roomId,
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _controlsAnimationController.forward();
      } else {
        _controlsAnimationController.reverse();
      }
    });
  }

  Future<void> _saveCanvasAsImage() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Saving image...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Capture the screenshot using RepaintBoundary
      final RenderRepaintBoundary? boundary = 
          _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to capture image'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to convert image'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final imageBytes = byteData.buffer.asUint8List();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voldermot_diary_$timestamp.png';

      // Use image_gallery_saver_plus - handles permissions automatically, no warnings!
      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        name: fileName,
        quality: 100,
        isReturnImagePathOfIOS: true,
      );

      if (mounted) {
        if (result['isSuccess'] == true || result['filePath'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Platform.isAndroid 
                  ? 'Image saved to gallery!'
                  : 'Image saved to: ${result['filePath'] ?? 'gallery'}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save image to gallery'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setAsWallpaper() async {
    try {
      // First save the image, then set it as wallpaper
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Saving and setting as wallpaper...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Capture the screenshot using RepaintBoundary
      final RenderRepaintBoundary? boundary = 
          _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to capture image'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to convert image'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final imageBytes = byteData.buffer.asUint8List();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voldermot_diary_wallpaper_$timestamp.png';

      // Save image first to get file path
      String? filePath;
      
      if (Platform.isAndroid) {
        // Save to temporary directory first
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(imageBytes);
        filePath = file.path;
        
        // Also save to gallery
        await ImageGallerySaverPlus.saveImage(
          imageBytes,
          name: fileName,
          quality: 100,
        );
        
        // Set as wallpaper using the saved file
        try {
          // Verify file exists
          final wallpaperFile = File(filePath);
          if (!await wallpaperFile.exists()) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Wallpaper file not found'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          final wallpaperManager = WallpaperManagerPlus();
          // Try with File object first, if that fails try with path string
          dynamic result;
          try {
            result = await wallpaperManager.setWallpaper(
              wallpaperFile,
              3, // 1 = HOME_SCREEN, 2 = LOCK_SCREEN, 3 = BOTH_SCREENS
            );
          } catch (e) {
            // If File object fails, try with path string
            try {
              result = await wallpaperManager.setWallpaper(
                filePath,
                3,
              );
            } catch (e2) {
              throw e2; // Throw the second error
            }
          }
          
          if (mounted) {
            // Check if result is true or a success string
            final success = result == true || 
                          (result is String && result.toLowerCase().contains('success')) ||
                          result.toString().toLowerCase().contains('success');
            
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Wallpaper set successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to set wallpaper. Result: $result'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error setting wallpaper: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        // iOS - wallpaper setting is more restricted
        // Just save to gallery
        await ImageGallerySaverPlus.saveImage(
          imageBytes,
          name: fileName,
          quality: 100,
          isReturnImagePathOfIOS: true,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image saved! On iOS, set wallpaper manually from Photos app.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Dispose animation controllers
    _controlsAnimationController.dispose();
    _colorPickerAnimationController.dispose();
    
    // Remove all socket listeners
    for (var cleanup in socketListeners) {
      cleanup();
    }
    socketListeners.clear();
    
    // Dispose all animation controllers
    for (var controller in strokeAnimations.values) {
      controller.stop();
      controller.dispose();
    }
    strokeAnimations.clear();
    
    // Clear state
    strokes.clear();
    currentStroke.clear();
    eraserTrail.clear();
    _deletedStrokeIds.clear(); // Clear deleted stroke tracking on dispose
    
    // Cancel debounce timer
    _requestStrokesDebounceTimer?.cancel();
    _requestStrokesDebounceTimer = null;
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        
        // Leave the room before navigating back
        if (widget.socket.connected) {
          widget.socket.emit('leave-room', {
            'roomId': widget.roomId,
            'userId': widget.userId,
          });
        }
        
        // Navigate back to ConnectionPage (main home screen) with existing socket
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => ConnectionPage(
                existingSocket: widget.socket,
                existingSocketId: widget.socketId,
              ),
            ),
            (route) => false, // Remove all previous routes
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            ConnectionStatusBar(
              connectionStatus: connectionStatus,
              statusColor: statusColor,
              usersInRoom: usersInRoom,
            ),
            
            // Drawing canvas (full screen)
            Positioned.fill(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Listener(
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: (event) {
                    if (selectedTool == 'eraser') {
                      _clearEraserTrail();
                    }
                    isDrawing = false;
                    currentStroke.clear();
                  },
                  child: GestureDetector(
                    // GestureDetector as fallback for devices that don't support pointer events
                    onPanStart: palmRejectionEnabled ? null : onPanStart,
                    onPanUpdate: palmRejectionEnabled ? null : onPanUpdate,
                    onPanEnd: palmRejectionEnabled ? null : onPanEnd,
                    child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      if (canvasSize != size) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              canvasSize = size;
                            });
                          }
                        });
                      }
                      
                      return Container(
                        color: Colors.black, // Black background
                        child: AnimatedBuilder(
                          animation: _eraserTrailFadeController ?? _controlsAnimationController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: DrawingPainter(
                                strokes: strokes,
                                currentStroke: currentStroke,
                                eraserTrail: eraserTrail,
                                eraserTrailOpacity: isErasing 
                                    ? 1.0 
                                    : (1.0 - (_eraserTrailFadeController?.value ?? 0.0)),
                                strokeColor: strokeColor,
                                strokeWidth: strokeWidth,
                                canvasSize: size,
                              ),
                              size: size,
                            );
                          },
                        ),
                      );
                    },
                    ),
                  ),
                ),
              ),
            ),
            
            DrawingBackButton(
              socket: widget.socket,
              socketId: widget.socketId,
              userId: widget.userId,
              roomId: widget.roomId,
            ),
            
            ControlButtons(
            controlsVisible: _controlsVisible,
            controlsAnimation: _controlsAnimation,
            selectedTool: selectedTool,
            palmRejectionEnabled: palmRejectionEnabled,
            strokeColor: strokeColor,
            colorOptions: colorOptions,
            colorPickerAnimation: _colorPickerAnimation,
            connectionStatus: connectionStatus,
            statusColor: statusColor,
            onRefresh: () {
              // Request fresh strokes from database
              _isEraseRefresh = false; // Allow animation on manual refresh
              
              // If disconnected, try to reconnect first
              if (!widget.socket.connected) {
                print('🔄 Not connected, attempting to reconnect...');
                setState(() {
                  connectionStatus = 'Connecting...';
                  statusColor = Colors.orange;
                });
                widget.socket.connect();
                
                // Wait for connection, then request strokes
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (mounted && widget.socket.connected) {
                    // Rejoin room first
                    widget.socket.emit('join-room', {
                      'roomId': widget.roomId,
                      'userId': widget.userId,
                    });
                    
                    // Then request strokes
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        widget.socket.emit('request-strokes', {
                          'roomId': widget.roomId,
                        });
                      }
                    });
                  }
                });
              } else {
                // Already connected, just request fresh strokes
                widget.socket.emit('request-strokes', {
                  'roomId': widget.roomId,
                });
              }
            },
            onToggleControls: _toggleControls,
            onPenSelected: () {
              if (selectedTool == 'eraser') {
                _clearEraserTrail();
              }
              setState(() {
                selectedTool = 'pen';
              });
            },
            onEraserSelected: () {
              if (selectedTool == 'pen') {
                _clearEraserTrail();
              }
              setState(() {
                selectedTool = 'eraser';
                if (_colorPickerAnimationController.isCompleted) {
                  _colorPickerAnimationController.reverse();
                }
              });
            },
            onPalmRejectionToggled: () {
              setState(() {
                palmRejectionEnabled = !palmRejectionEnabled;
              });
            },
            onColorSelected: (color) {
              setState(() {
                strokeColor = color;
              });
            },
            onColorPickerToggle: () {
              if (_colorPickerAnimationController.isCompleted) {
                _colorPickerAnimationController.reverse();
              } else {
                _colorPickerAnimationController.forward();
              }
            },
            onDownload: _saveCanvasAsImage,
            // onSetWallpaper: _setAsWallpaper, // Commented out for now
            onSetWallpaper: () {}, // Placeholder to avoid errors
          ),
        ],
      ),
      ),
    );
  }
}
