import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
        
        // Only process strokes for the current room
        if (stroke.roomId != widget.roomId) {
          print('⚠️ Ignoring stroke from different room: ${stroke.roomId} (current: ${widget.roomId})');
          return;
        }
        
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
      
      final clearedRoomId = data['roomId'] as String?;
      // Only process clear events for the current room
      if (clearedRoomId != null && clearedRoomId != widget.roomId) {
        return;
      }
      
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
      
      final deletedRoomId = data['roomId'] as String?;
      // Only process delete events for the current room
      if (deletedRoomId != null && deletedRoomId != widget.roomId) {
        return;
      }
      
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
          ),
        ],
      ),
      ),
    );
  }
}
