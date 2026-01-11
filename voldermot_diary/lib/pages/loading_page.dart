import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'drawing_page.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LoadingPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final String socketId;
  final IO.Socket socket;

  const LoadingPage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.socketId,
    required this.socket,
  });

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    // Navigate to drawing page after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DrawingPage(
              socket: widget.socket,
              socketId: widget.socketId,
              roomId: widget.roomId,
              userId: widget.userId,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Get screen dimensions
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          
          // Calculate animation size - use 80% of width, but ensure it fits height too
          // Reserve space for text at bottom (about 120px)
          final availableHeight = screenHeight - 120;
          final availableWidth = screenWidth * 0.8;
          
          // Maintain aspect ratio - assume square-ish animation (adjust if needed)
          // Use the smaller dimension to ensure it fits both width and height
          double animationSize = availableWidth < availableHeight 
              ? availableWidth 
              : availableHeight;
          
          // Ensure minimum and maximum sizes
          animationSize = animationSize.clamp(200.0, screenWidth * 0.9);
          
          return Stack(
            children: [
              // Center the animation with quote below
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: animationSize,
                      height: animationSize,
                      child: AspectRatio(
                        aspectRatio: 1.0, // Maintain square aspect ratio
                        child: Lottie.asset(
                          'assets/animations/WingardiumLeviosa.json',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback animation if Lottie file not found
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.5),
                                  width: 3,
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Hermione's famous quote
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        "It's Levi-O-sa, not Levio-SA!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.amber.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom section with loading text and room info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Loading text
                        Text(
                          'Loading...',
                          style: TextStyle(
                            color: Colors.amber.withOpacity(0.8),
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Room info
                        Text(
                          'Joining room: ${widget.roomId}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
