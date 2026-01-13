import 'package:flutter/material.dart';

class ColorPicker extends StatelessWidget {
  final List<Map<String, dynamic>> colorOptions;
  final String selectedColor;
  final Function(String) onColorSelected;
  final Animation<double> animation;
  final String selectedTool;

  const ColorPicker({
    super.key,
    required this.colorOptions,
    required this.selectedColor,
    required this.onColorSelected,
    required this.animation,
    required this.selectedTool,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (selectedTool != 'pen' || animation.value == 0) {
          return const SizedBox.shrink();
        }
        
        final calculatedHeight = (colorOptions.length * 32.0) + 16.0;
        final height = animation.value * calculatedHeight;
        final opacity = animation.value;
        
        return Opacity(
          opacity: opacity,
          child: ClipRect(
            child: SizedBox(
              height: height,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: colorOptions.map((colorOption) {
                    final isSelected = colorOption['color'] == selectedColor;
                    final displayColor = colorOption['displayColor'] as Color;
                    return GestureDetector(
                      onTap: () => onColorSelected(colorOption['color'] as String),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: displayColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.amber : Colors.grey[600]!,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
