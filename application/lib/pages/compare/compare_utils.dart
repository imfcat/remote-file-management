import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum CompareMode {
  sideBySide, // 两栏对比
  overlay, // 重合对比
}

/// 绘制差异像素点
class DiffPainter extends CustomPainter {
  final ui.Image? diffImage;
  final Color highlightColor;
  final double opacity;

  DiffPainter({
    required this.diffImage,
    required this.highlightColor,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 如果没有差异图或透明度为0，则不绘制
    if (diffImage == null || opacity <= 0) return;

    // 将白色蒙版替换为高亮颜色
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(
        highlightColor.withValues(alpha: opacity),
        BlendMode.srcIn,
      );

    final double imgWidth = diffImage!.width.toDouble();
    final double imgHeight = diffImage!.height.toDouble();
    final double canvasWidth = size.width;
    final double canvasHeight = size.height;

    // 计算宽高比
    final double imageAspectRatio = imgWidth / imgHeight;
    final double canvasAspectRatio = canvasWidth / canvasHeight;

    double drawWidth, drawHeight, dx, dy;

    // 比较图片和画布的宽高比，确定缩放基准
    if (imageAspectRatio > canvasAspectRatio) {
      // 图片相对更宽：以画布宽度为基准，上下留白，垂直居中
      drawWidth = canvasWidth;
      drawHeight = canvasWidth / imageAspectRatio;
      dx = 0;
      dy = (canvasHeight - drawHeight) / 2.0;
    } else {
      // 图片相对更高：以画布高度为基准，左右留白，水平居中
      drawHeight = canvasHeight;
      drawWidth = canvasHeight * imageAspectRatio;
      dy = 0;
      dx = (canvasWidth - drawWidth) / 2.0;
    }

    // 源矩形 差异蒙版图的完整区域
    final src = Rect.fromLTWH(0, 0, imgWidth, imgHeight);

    // 目标矩形 计算出的实际显示区域
    final dst = Rect.fromLTWH(dx, dy, drawWidth, drawHeight);

    // 将差异图绘制到计算出的区域内
    canvas.drawImageRect(diffImage!, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant DiffPainter oldDelegate) {
    return oldDelegate.diffImage != diffImage ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.opacity != opacity;
  }
}

/// 自定义ImageProvider
class UiImageProvider extends ImageProvider<UiImageProvider> {
  final ui.Image image;

  UiImageProvider(this.image);

  @override
  Future<UiImageProvider> obtainKey(final ImageConfiguration configuration) {
    return SynchronousFuture<UiImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(UiImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      Future.value(
        ImageInfo(
          image: image,
          scale: 1.0,
        ),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UiImageProvider &&
              runtimeType == other.runtimeType &&
              image == other.image;

  @override
  int get hashCode => image.hashCode;
}