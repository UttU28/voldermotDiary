import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'color_picker.dart';

class ControlButtons extends StatelessWidget {
  final bool controlsVisible;
  final Animation<double> controlsAnimation;
  final String selectedTool;
  final bool palmRejectionEnabled;
  final String strokeColor;
  final List<Map<String, dynamic>> colorOptions;
  final Animation<double> colorPickerAnimation;
  final VoidCallback onToggleControls;
  final VoidCallback onPenSelected;
  final VoidCallback onEraserSelected;
  final VoidCallback onPalmRejectionToggled;
  final Function(String) onColorSelected;
  final VoidCallback onColorPickerToggle;
  final VoidCallback onDownload;
  final VoidCallback onSetWallpaper;

  static const String _penLottie = 'https://lottie.host/embed/2g9f9i9i-7j8e-8g2f-3j6h-5i7j8e9f/2g9f9i9i.json';
  static const String _arrowDownLottie = 'https://lottie.host/embed/9d6c6f6f-4g5b-5d9c-0g3e-2f4g5b6c7d/9d6c6f6f.json';
  static const String _arrowUpLottie = 'https://lottie.host/embed/0e7d7g7g-5h6c-6e0d-1h4f-3g5h6c7d/0e7d7g7g.json';

  const ControlButtons({
    super.key,
    required this.controlsVisible,
    required this.controlsAnimation,
    required this.selectedTool,
    required this.palmRejectionEnabled,
    required this.strokeColor,
    required this.colorOptions,
    required this.colorPickerAnimation,
    required this.onToggleControls,
    required this.onPenSelected,
    required this.onEraserSelected,
    required this.onPalmRejectionToggled,
    required this.onColorSelected,
    required this.onColorPickerToggle,
    required this.onDownload,
    required this.onSetWallpaper,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 48,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(),
          _buildAnimatedControls(),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return Container(
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
          onTap: onToggleControls,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Opacity(
              opacity: 0.7,
              child: controlsVisible
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
    );
  }

  Widget _buildAnimatedControls() {
    return AnimatedBuilder(
      animation: controlsAnimation,
      builder: (context, child) {
        final animationValue = controlsAnimation.value;
        
        if (animationValue <= 0.3) {
          return const SizedBox.shrink();
        }
        
        final opacity = ((animationValue - 0.3) / 0.7).clamp(0.0, 1.0);
        final scale = ((animationValue - 0.3) / 0.7).clamp(0.0, 1.0);
        
        return RepaintBoundary(
          child: IgnorePointer(
            ignoring: !controlsVisible,
            child: Opacity(
              opacity: opacity,
              child: ClipRect(
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPenButton(),
                      ColorPicker(
                        colorOptions: colorOptions,
                        selectedColor: strokeColor,
                        onColorSelected: onColorSelected,
                        animation: colorPickerAnimation,
                        selectedTool: selectedTool,
                      ),
                      _buildEraserButton(),
                      _buildPalmRejectionButton(),
                      _buildDownloadButton(),
                      // _buildSetWallpaperButton(), // Commented out for now
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPenButton() {
    return Container(
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
            onPenSelected();
            onColorPickerToggle();
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
    );
  }

  Widget _buildEraserButton() {
    return Container(
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
          onTap: onEraserSelected,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Opacity(
              opacity: selectedTool == 'eraser' ? 1.0 : 0.6,
              child: CustomPaint(
                size: const Size(24, 24),
                painter: EraserIconPainter(
                  color: selectedTool == 'eraser' ? Colors.amber : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPalmRejectionButton() {
    return Container(
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
          onTap: onPalmRejectionToggled,
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
    );
  }

  Widget _buildDownloadButton() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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
          onTap: onDownload,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: const Opacity(
              opacity: 0.9,
              child: Icon(
                Icons.download,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetWallpaperButton() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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
          onTap: onSetWallpaper,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: const Opacity(
              opacity: 0.9,
              child: Icon(
                Icons.wallpaper,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EraserIconPainter extends CustomPainter {
  final Color color;

  EraserIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.5;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw eraser body (rounded rectangle)
    final eraserRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.7, size.height * 0.5),
      const Radius.circular(2),
    );
    canvas.drawRRect(eraserRect, paint);

    // Draw metal band at the top
    final bandRect = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.25,
      size.width * 0.7,
      size.height * 0.12,
    );
    final bandPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(bandRect, bandPaint);
    canvas.drawRect(bandRect, strokePaint);

    // Draw eraser tip (slightly rounded bottom)
    final tipPath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.75)
      ..lineTo(size.width * 0.25, size.height * 0.85)
      ..lineTo(size.width * 0.75, size.height * 0.85)
      ..lineTo(size.width * 0.85, size.height * 0.75)
      ..close();
    canvas.drawPath(tipPath, paint);

    // Add some texture lines on the eraser body
    final texturePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
    for (double i = 0.35; i < 0.75; i += 0.08) {
      canvas.drawLine(
        Offset(size.width * 0.2, size.height * i),
        Offset(size.width * 0.8, size.height * i),
        texturePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is EraserIconPainter && oldDelegate.color != color;
  }
}
