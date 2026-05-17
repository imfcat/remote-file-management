import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'compare_utils.dart';

class CompareToolbar extends StatelessWidget {
  final CompareMode currentMode;
  final Color highlightColor;
  final double highlightOpacity;
  final double sliderValue;
  final bool isCalculatingDiff;
  final bool showImageInfo;

  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onResetZoom;
  final VoidCallback onToggleInfo;

  const CompareToolbar({
    super.key,
    required this.currentMode,
    required this.highlightColor,
    required this.highlightOpacity,
    required this.sliderValue,
    required this.isCalculatingDiff,
    required this.showImageInfo,
    required this.onColorChanged,
    required this.onOpacityChanged,
    required this.onSliderChanged,
    required this.onResetZoom,
    required this.onToggleInfo,
  });

  void _pickHighlightColor(BuildContext context) {
    Color tempColor = highlightColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择高亮颜色'),
        backgroundColor: Colors.grey[850],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: highlightColor,
            onColorChanged: (color) => tempColor = color
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              onColorChanged(tempColor);
              Navigator.pop(context);
            },
            child: const Text('确认', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentMode == CompareMode.sideBySide) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.grey[900],
        child: Row(
          children: [
            const Text(
              '差异高亮：',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            // 颜色选择按钮
            GestureDetector(
              onTap: () => _pickHighlightColor(context),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: highlightColor.withValues(alpha: highlightOpacity),
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 透明度滑块
            Expanded(
              child: Slider(
                value: highlightOpacity,
                min: 0.0,
                max: 1.0,
                activeColor: highlightColor,
                inactiveColor: Colors.grey[700],
                onChanged: onOpacityChanged,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(highlightOpacity * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            // 加载状态指示器
            if (isCalculatingDiff)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left:12),
              child: IconButton(
                icon: const Icon(Icons.zoom_out_map, color: Colors.white, size: 20),
                tooltip: '重置缩放',
                onPressed: onResetZoom,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:4),
              child: IconButton(
                icon: Icon(
                  showImageInfo ? Icons.info : Icons.info_outline,
                  color: showImageInfo ? Colors.blueAccent : Colors.white,
                  size: 20,
                ),
                tooltip: showImageInfo ? '隐藏图片信息' : '显示图片信息',
                onPressed: onToggleInfo,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        color: Colors.grey[900],
        child: Row(
          children: [
            Expanded(
              child: Slider(
                value: sliderValue,
                min: 0.0,
                max: 1.0,
                activeColor: Colors.blueAccent,
                inactiveColor: Colors.grey[700],
                label: '左: ${((1 - sliderValue) * 100).round()}% | 右: ${(sliderValue * 100).round()}%',
                onChanged: onSliderChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.zoom_out_map, color: Colors.white, size: 20),
                tooltip: '重置缩放',
                onPressed: onResetZoom,
              ),
            ),
          ],
        ),
      );
    }
  }
}