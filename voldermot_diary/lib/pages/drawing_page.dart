import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:lottie/lottie.dart';
import '../models/stroke.dart';
import '../models/animated_stroke.dart';

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
  
  // Canvas dimensions for coordinate normalization
  Size? canvasSize;

  // Drawing settings
  final String strokeColor = '#8B6914';
  final double strokeWidth = 4.0;
  final double animationDuration = 0.5;
  
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

  // Lottie animation URLs from LottieFiles (free animations)
  // Replace these with your preferred LottieFiles URLs from https://lottiefiles.com/
  // Popular free animations:
  // - Back arrow: Search "arrow left" or "back"
  // - Trash: Search "delete" or "trash"
  // - Pen: Search "pen" or "pencil"
  // - Eraser: Search "eraser" or "delete"
  // - Arrows: Search "arrow down" or "arrow up"
  // 
  // To use local files, download JSON and use: Lottie.asset('assets/animations/name.json')
  static const String _backArrowLottie = 'https://lottie.host/embed/8c5b5e5e-3f4a-4c8b-9f2d-1e3f4a5b6c7d/8c5b5e5e.json';
  static const String _trashLottie = 'https://lottie.host/embed/1f8e8h8h-6i7d-7f1e-2i5g-4h6i7d8e/1f8e8h8h.json';
  static const String _penLottie = 'https://lottie.host/embed/2g9f9i9i-7j8e-8g2f-3j6h-5i7j8e9f/2g9f9i9i.json';
  static const String _eraserLottie = 'https://lottie.host/embed/4i1h1k1k-9l0g-0i4h-5l8j-7k9l0g1h/4i1h1k1k.json';
  static const String _arrowDownLottie = 'https://lottie.host/embed/9d6c6f6f-4g5b-5d9c-0g3e-2f4g5b6c7d/9d6c6f6f.json';
  static const String _arrowUpLottie = 'https://lottie.host/embed/0e7d7g7g-5h6c-6e0d-1h4f-3g5h6c7d/0e7d7g7g.json';

  @override
  void initState() {
    super.initState();
    setupSocketListeners();
    
    // Request existing strokes after a short delay to ensure listeners are ready
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
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
      
      print('📥 Received load-strokes event with data: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}');
      
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
        
        // Add strokes and animate them all in 1 second
        setState(() {
          strokes.clear();
          strokes.addAll(loadedStrokes);
        });
        
        // Animate all loaded strokes together in 1 second
        if (loadedStrokes.isNotEmpty && mounted) {
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
        final strokeId = '${stroke.userId}_${stroke.createdAt}';
        
        if (stroke.userId == widget.userId || stroke.socketId == widget.socketId) {
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
      setState(() {
        strokes.clear();
        currentStroke.clear();
      });
    };
    
    widget.socket.on('canvas-cleared', clearHandler);
    socketListeners.add(() => widget.socket.off('canvas-cleared', clearHandler));

    // Listen for connection status
    final statusHandler = (data) {
      if (!mounted) return;
      setState(() {
        connectionStatus = data['status'] ?? 'Connected';
        statusColor = connectionStatus == 'Connected' ? Colors.green : Colors.red;
      });
    };
    
    widget.socket.on('connection-status', statusHandler);
    socketListeners.add(() => widget.socket.off('connection-status', statusHandler));

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
      final userId = data['userId'] as String?;
      final createdAt = data['createdAt'] as int?;
      
      if (userId != null && createdAt != null) {
        setState(() {
          strokes.removeWhere((s) => 
            s.stroke.userId == userId && 
            s.stroke.createdAt == createdAt
          );
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
    final Set<Stroke> strokesToDelete = {};
    
    // Check each stroke's points to see if any are within eraser radius
    for (var animatedStroke in strokes) {
      for (var point in animatedStroke.stroke.points) {
        final dx = point.x - normalizedX;
        final dy = point.y - normalizedY;
        final distance = dx * dx + dy * dy;
        
        // If any point of the stroke is within eraser radius, mark for deletion
        if (distance < (eraserRadius * eraserRadius)) {
          strokesToDelete.add(animatedStroke.stroke);
          break; // No need to check other points of this stroke
        }
      }
    }
    
    // Delete all strokes that came in contact
    for (var stroke in strokesToDelete) {
      _deleteStroke(stroke);
    }
  }
  
  void _deleteStroke(Stroke stroke) {
    if (!mounted) return;
    
    // Remove from local state
    setState(() {
      strokes.removeWhere((s) => 
        s.stroke.createdAt == stroke.createdAt && 
        s.stroke.userId == stroke.userId
      );
    });
    
    // Send delete request to server
    widget.socket.emit('delete-stroke', {
      'roomId': widget.roomId,
      'strokeId': '${stroke.userId}_${stroke.createdAt}',
      'userId': stroke.userId,
      'createdAt': stroke.createdAt,
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

  @override
  void dispose() {
    // Dispose controls animation controller
    _controlsAnimationController.dispose();
    
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
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Connection status bar
          Positioned(
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
          ),
          
          // Drawing canvas (full screen)
          Positioned.fill(
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
          
          // Floating action buttons
          // Top left - Back button
          Positioned(
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
                  onTap: () => Navigator.pop(context),
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
          ),
          
          // Top right - Control buttons (trash, pen, eraser, toggle) - animated
          Positioned(
            top: 48,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle controls button - always visible at top
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                      onTap: _toggleControls,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Opacity(
                          opacity: 0.7,
                          child: _controlsVisible
                              ? Lottie.network(
                                  _arrowDownLottie,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24);
                                  },
                                )
                              : Lottie.network(
                                  _arrowUpLottie,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 24);
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Animated controls (trash, pen, eraser) - fade and popup
                AnimatedBuilder(
                  animation: _controlsAnimation,
                  builder: (context, child) {
                    // Fade and scale (popup) animation
                    final animationValue = _controlsAnimation.value;
                    
                    // Only show controls if animation value is greater than 0.3 to completely prevent flash
                    if (animationValue <= 0.3) {
                      return const SizedBox.shrink();
                    }
                    
                    // Clamp opacity and scale to smooth values
                    final opacity = ((animationValue - 0.3) / 0.7).clamp(0.0, 1.0);
                    final scale = ((animationValue - 0.3) / 0.7).clamp(0.0, 1.0);
                    
                    return RepaintBoundary(
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: Opacity(
                          opacity: opacity,
                          child: ClipRect(
                            child: Transform.scale(
                              scale: scale,
                              alignment: Alignment.topCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Delete all button (trash)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
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
                                        onTap: clearCanvas,
                                        borderRadius: BorderRadius.circular(30),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          child: Opacity(
                                            opacity: 0.7,
                                            child: ColorFiltered(
                                              colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
                                              child: Lottie.network(
                                                _trashLottie,
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Icon(Icons.delete_outline, color: Colors.red, size: 24);
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Pen button
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
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
                                        // Clear eraser trail when switching to pen
                                        if (selectedTool == 'eraser') {
                                          _clearEraserTrail();
                                        }
                                        setState(() {
                                          selectedTool = 'pen';
                                        });
                                      },
                                        borderRadius: BorderRadius.circular(30),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          child: Opacity(
                                            opacity: selectedTool == 'pen' ? 1.0 : 0.6,
                                            child: ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                selectedTool == 'pen' ? Colors.amber : Colors.white,
                                                BlendMode.srcIn
                                              ),
                                              child: Lottie.network(
                                                _penLottie,
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.contain,
                                                repeat: selectedTool == 'pen',
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.edit,
                                                    color: selectedTool == 'pen' ? Colors.amber : Colors.white,
                                                    size: 24
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Eraser button
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
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
                                          // Clear any existing trail when switching to eraser
                                          if (selectedTool == 'pen') {
                                            _clearEraserTrail();
                                          }
                                          setState(() {
                                            selectedTool = 'eraser';
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(30),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          child: Opacity(
                                            opacity: selectedTool == 'eraser' ? 1.0 : 0.6,
                                            child: ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                selectedTool == 'eraser' ? Colors.amber : Colors.white,
                                                BlendMode.srcIn
                                              ),
                                              child: Lottie.network(
                                                _eraserLottie,
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.contain,
                                                repeat: selectedTool == 'eraser',
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.auto_fix_high,
                                                    color: selectedTool == 'eraser' ? Colors.amber : Colors.white,
                                                    size: 24
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Palm rejection toggle button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900]!.withOpacity(0.9),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: palmRejectionEnabled 
                                            ? Colors.amber.withOpacity(0.5) 
                                            : Colors.grey[700]!.withOpacity(0.5), 
                                        width: palmRejectionEnabled ? 2 : 1
                                      ),
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
                                          setState(() {
                                            palmRejectionEnabled = !palmRejectionEnabled;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(30),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          child: Opacity(
                                            opacity: palmRejectionEnabled ? 1.0 : 0.6,
                                            child: ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                palmRejectionEnabled ? Colors.amber : Colors.white,
                                                BlendMode.srcIn
                                              ),
                                              child: Icon(
                                                palmRejectionEnabled 
                                                    ? Icons.pan_tool 
                                                    : Icons.pan_tool_alt,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<AnimatedStroke> strokes;
  final List<StrokePoint> currentStroke;
  final List<Offset> eraserTrail;
  final double eraserTrailOpacity;
  final String strokeColor;
  final double strokeWidth;
  final Size canvasSize;

  DrawingPainter({
    required this.strokes,
    required this.currentStroke,
    required this.eraserTrail,
    required this.eraserTrailOpacity,
    required this.strokeColor,
    required this.strokeWidth,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background is handled by Container, so no need to draw it here

    // Draw all completed strokes (animated or complete)
    for (final animatedStroke in strokes) {
      final visiblePoints = animatedStroke.visiblePoints;
      if (visiblePoints.isNotEmpty) {
        _drawStroke(canvas, visiblePoints, animatedStroke.stroke.color, animatedStroke.stroke.width);
      }
    }

    // Draw current stroke being drawn (with glow effect)
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, strokeColor, strokeWidth, withGlow: true);
    }

    // Draw eraser trail only if opacity > 0
    if (eraserTrail.length > 1 && eraserTrailOpacity > 0) {
      _drawEraserTrail(canvas, eraserTrail, eraserTrailOpacity);
    }
  }

  void _drawEraserTrail(Canvas canvas, List<Offset> trail, double opacity) {
    if (trail.length < 2 || opacity <= 0) return;

    final path = Path();
    path.moveTo(trail[0].dx, trail[0].dy);

    // Draw smooth trail with fade effect at the end
    for (int i = 1; i < trail.length; i++) {
      if (i == 1) {
        path.lineTo(trail[i].dx, trail[i].dy);
      } else {
        final prevPoint = trail[i - 1];
        final currentPoint = trail[i];
        final controlX = (prevPoint.dx + currentPoint.dx) / 2;
        final controlY = (prevPoint.dy + currentPoint.dy) / 2;
        path.quadraticBezierTo(prevPoint.dx, prevPoint.dy, controlX, controlY);
      }
    }

    // Draw trail with transparent white/grey color and fade opacity
    // Fade out the end of the trail for smoother effect
    final baseOpacity = 0.3 * opacity;
    final trailPaint = Paint()
      ..color = Colors.white.withOpacity(baseOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, trailPaint);
  }

  void _drawStroke(Canvas canvas, List<StrokePoint> points, String color, double width, {bool withGlow = false}) {
    if (points.length < 2) return;

    // Convert normalized coordinates (0.0-1.0) to screen coordinates
    final screenPoints = points.map((p) => Offset(
      p.x * canvasSize.width,
      p.y * canvasSize.height,
    )).toList();

    final path = Path();
    path.moveTo(screenPoints[0].dx, screenPoints[0].dy);

    // Use smooth curves for better drawing experience
    for (int i = 1; i < screenPoints.length; i++) {
      if (i == 1) {
        path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
      } else {
        // Use quadratic bezier for smoother lines
        final prevPoint = screenPoints[i - 1];
        final currentPoint = screenPoints[i];
        final controlX = (prevPoint.dx + currentPoint.dx) / 2;
        final controlY = (prevPoint.dy + currentPoint.dy) / 2;
        path.quadraticBezierTo(prevPoint.dx, prevPoint.dy, controlX, controlY);
      }
    }

    // Draw glow effect for current stroke
    if (withGlow) {
      final glowPaint = Paint()
        ..color = _parseColor(color).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, glowPaint);
    }

    // Draw main stroke
    final paint = Paint()
      ..color = _parseColor(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return const Color(0xFF3b2f1e); // Default brown
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return strokes.length != oldDelegate.strokes.length ||
        currentStroke.length != oldDelegate.currentStroke.length ||
        eraserTrail.length != oldDelegate.eraserTrail.length ||
        eraserTrailOpacity != oldDelegate.eraserTrailOpacity;
  }
}
