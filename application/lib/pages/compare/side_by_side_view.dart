import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'compare_utils.dart';

class SideBySideView extends StatefulWidget {
  final ui.Image uiImage1;
  final ui.Image uiImage2;
  final ui.Image? diffImage;
  final Color highlightColor;
  final double highlightOpacity;
  final TransformationController syncTransformationController;
  final bool showImageInfo;
  final Map<String, dynamic> leftImageDetail;
  final Map<String, dynamic> rightImageDetail;
  final bool isDeletingLeft;
  final bool isDeletingRight;
  final VoidCallback onDeleteLeft;
  final VoidCallback onDeleteRight;

  const SideBySideView({
    super.key,
    required this.uiImage1,
    required this.uiImage2,
    this.diffImage,
    required this.highlightColor,
    required this.highlightOpacity,
    required this.syncTransformationController,
    required this.showImageInfo,
    required this.leftImageDetail,
    required this.rightImageDetail,
    required this.isDeletingLeft,
    required this.isDeletingRight,
    required this.onDeleteLeft,
    required this.onDeleteRight,
  });

  @override
  State<SideBySideView> createState() => _SideBySideViewState();
}

class _SideBySideViewState extends State<SideBySideView> {
  bool _expandLeftInfo = false;
  bool _expandRightInfo = false;

  Widget _buildExpandableImageInfo({required Map<String, dynamic> info, required bool isLeft}) {
    final isExpanded = isLeft ? _expandLeftInfo : _expandRightInfo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.black87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('文件名：${info['fileName'] ?? '未知'}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Row(
                      children: [
                        Text('文件大小：${info['formatSize'] ?? '0 B'}', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                        const SizedBox(width: 16),
                        Text('像素尺寸：${info['pixelWidth']} × ${info['pixelHeight']}', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                      ]
                    ),
                    Text('文件路径：${info['filePath'] ?? '未知'}', style: TextStyle(color: Colors.grey[400], fontSize: 9, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              // 展开收起按钮
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.blueAccent,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    if(isLeft) {
                      _expandLeftInfo = !_expandLeftInfo;
                    } else {
                      _expandRightInfo = !_expandRightInfo;
                    }
                  });
                },
              ),
            ],
          ),
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 6, left: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.grey[900]!.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 1)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('高级信息', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w500)),
                  Divider(height: 8, color: Colors.grey[700]),
                  // 像素信息
                  Text('宽高比例：${info['aspectRatio']}', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                  Text('总像素量：${info['totalPixels']}', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                  const SizedBox(height: 4),
                  // 色彩信息
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左图
        Expanded(
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: widget.syncTransformationController,
                minScale: 0.1,
                maxScale: 10.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: UiImageProvider(widget.uiImage1),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    CustomPaint(
                      painter: DiffPainter(
                        diffImage: widget.diffImage,
                        highlightColor: widget.highlightColor,
                        opacity: widget.highlightOpacity,
                      ),
                      size: Size.infinite,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: widget.isDeletingLeft
                    ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                    : InkWell(
                  onTap: widget.onDeleteLeft,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16)
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 20
                        )
                      )
                ),
              ),
                // 左侧可展开的图片信息栏
              if (widget.showImageInfo)
                Positioned(
                    left:0,
                    right:0,
                    bottom:0,
                  child: _buildExpandableImageInfo(
                    info: widget.leftImageDetail,
                    isLeft: true
                  )
                ),
            ],
          ),
        ),
        Container(width: 1, color: Colors.white30),
        // 右图
        Expanded(
          child: Stack(
            children: [
                // 缩放控制层
              InteractiveViewer(
                transformationController: widget.syncTransformationController,
                minScale: 0.1,
                maxScale: 10.0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: UiImageProvider(widget.uiImage2),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    CustomPaint(
                      painter: DiffPainter(
                        diffImage: widget.diffImage,
                        highlightColor: widget.highlightColor,
                        opacity: widget.highlightOpacity,
                      ),
                      size: Size.infinite,
                    ),
                  ],
                ),
              ),
                // 右侧删除按钮
              Positioned(
                top: 16,
                right: 16,
                child: widget.isDeletingRight
                    ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                  : InkWell(
                  onTap: widget.onDeleteRight,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size:20)
                  ),
                ),
              ),
              if (widget.showImageInfo)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildExpandableImageInfo(info: widget.rightImageDetail, isLeft: false),
                ),
            ],
          ),
        ),
      ],
    );
  }
}