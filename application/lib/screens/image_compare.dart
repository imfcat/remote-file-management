import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import '../services/file_url.dart';
import '../services/file_record.dart';
import '../utils/custom_cache.dart';
import '../services/api_service.dart';
import '../widget/notification.dart';

enum CompareMode {
  sideBySide, // 两栏对比
  overlay, // 重合对比
}

class ImageComparePage extends StatefulWidget {
  final FileRecord image1;
  final FileRecord image2;
  final String backendUrl;

  const ImageComparePage({
    super.key,
    required this.image1,
    required this.image2,
    required this.backendUrl,
  });

  @override
  State<ImageComparePage> createState() => _ImageComparePageState();
}

class _ImageComparePageState extends State<ImageComparePage> {
  CompareMode _currentMode = CompareMode.sideBySide;
  Color _highlightColor = Colors.amber;
  double _highlightOpacity = 0.5;
  double _sliderValue = 0.5; // 0左图透明 1右图透明 0.5半透明
  ui.Image? _uiImage1;
  ui.Image? _uiImage2;
  ui.Image? _diffImage;
  bool _isCalculatingDiff = false;
  bool _showImageInfo = false; // 是否显示图片信息
  bool _isDeletingLeft = false; // 左侧图片删除中状态
  bool _isDeletingRight = false; // 右侧图片删除中状态
  bool _expandLeftInfo = false; // 左侧图片高级信息展开/收起
  bool _expandRightInfo = false; // 右侧图片高级信息展开/收起
  Map<String, dynamic> _leftImageDetail = {}; // 左侧图片详细信息
  Map<String, dynamic> _rightImageDetail = {}; // 右侧图片详细信息

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  /// 加载图片并转换
  Future<void> _loadImages() async {
    try {
      final url1 = fileContentUrl(context, widget.image1.file);
      final url2 = fileContentUrl(context, widget.image2.file);

      _uiImage1 = await _loadUiImageFromUrl(url1);
      _uiImage2 = await _loadUiImageFromUrl(url2);

      // 计算像素差异
      if (_uiImage1 != null && _uiImage2 != null) {
        await _calculatePixelDiff();
        // 解析图片详细信息
        if(mounted) {
          setState(() {
            _leftImageDetail = _getImageAllInfo(_uiImage1!, widget.image1);
            _rightImageDetail = _getImageAllInfo(_uiImage2!, widget.image2);
          });
        }
      }

      // 首次加载完成后刷新ui
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppNotification.show(message: '图片加载失败：$e', type: NotificationType.error, duration: Duration(seconds: 2));
        });
      }
    }
  }

  /// 从URL加载ui.Image
  Future<ui.Image> _loadUiImageFromUrl(String url) async {
    final imageProvider = CachedNetworkImageProvider(
      url,
      cacheManager: customCacheManager(),
    );
    final completer = Completer<ui.Image>();

    final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
          (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
          stream.removeListener(listener);
        }
      },
      onError: (Object exception, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
          stream.removeListener(listener);
        }
      },
    );

    stream.addListener(listener);

    completer.future.catchError((_) {
      stream.removeListener(listener);
    });

    return completer.future;
  }

  /// 差异计算参数的封装
  /// 返回差异蒙版图片的原始色彩字节数据
  static Future<Uint8List?> _isolateCalculateDiff(Map<String, dynamic> params) async {
    final ByteData bytes1 = params['bytes1'];
    final int width1 = params['width1'];
    final int height1 = params['height1'];

    final ByteData bytes2 = params['bytes2'];
    final int width2 = params['width2'];
    final int height2 = params['height2'];

    final img1 = img.Image.fromBytes(
      width: width1,
      height: height1,
      bytes: bytes1.buffer,
      numChannels: 4,
    );

    final img2 = img.Image.fromBytes(
      width: width2,
      height: height2,
      bytes: bytes2.buffer,
      numChannels: 4,
    );

    // 统一尺寸
    final targetWidth = img1.width < img2.width ? img1.width : img2.width;
    final targetHeight = img1.height < img2.height ? img1.height : img2.height;

    final img.Image resizedImg1 = (img1.width == targetWidth && img1.height == targetHeight)
        ? img1
        : img.copyResize(img1, width: targetWidth, height: targetHeight);

    final img.Image resizedImg2 = (img2.width == targetWidth && img2.height == targetHeight)
        ? img2
        : img.copyResize(img2, width: targetWidth, height: targetHeight);

    // 创建差异蒙版
    final int length = targetWidth * targetHeight * 4;
    final Uint8List diffBytes = Uint8List(length);

    // 逐像素对比并填充
    bool hasDiff = false;

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final pixel1 = resizedImg1.getPixel(x, y);
        final pixel2 = resizedImg2.getPixel(x, y);

        // rgb差异判断
        if (pixel1.r != pixel2.r ||
            pixel1.g != pixel2.g ||
            pixel1.b != pixel2.b) {

          hasDiff = true;

          // 计算索引
          final index = (y * targetWidth + x) * 4;

          // 设置为纯白色
          diffBytes[index] = 255;     // R
          diffBytes[index + 1] = 255; // G
          diffBytes[index + 2] = 255; // B
          diffBytes[index + 3] = 255; // A
        }
      }
    }

    return hasDiff ? diffBytes : null;
  }

  /// 计算两张图片的像素差异
  Future<void> _calculatePixelDiff() async {
    if (_uiImage1 == null || _uiImage2 == null) return;

    // 清理旧数据
    _diffImage?.dispose();
    _diffImage = null;

    setState(() => _isCalculatingDiff = true);

    try {
      final byteData1 = await _uiImage1!.toByteData(format: ui.ImageByteFormat.rawRgba);
      final byteData2 = await _uiImage2!.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData1 == null || byteData2 == null) throw Exception("无法获取图片数据");

      // 使用较小的尺寸作为基准
      final w = _uiImage1!.width < _uiImage2!.width ? _uiImage1!.width : _uiImage2!.width;
      final h = _uiImage1!.height < _uiImage2!.height ? _uiImage1!.height : _uiImage2!.height;

      // 计算，返回Uint8List
      final Uint8List? diffRawBytes = await compute(_isolateCalculateDiff, {
        'bytes1': byteData1,
        'width1': _uiImage1!.width,
        'height1': _uiImage1!.height,
        'bytes2': byteData2,
        'width2': _uiImage2!.width,
        'height2': _uiImage2!.height,
      });

      // 将原始字节转回ui.Image
      if (diffRawBytes != null) {
        final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(diffRawBytes);
        final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
          buffer,
          width: w,
          height: h,
          pixelFormat: ui.PixelFormat.rgba8888,
        );
        final ui.Codec codec = await descriptor.instantiateCodec();
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        _diffImage = frameInfo.image;
      }

      if (mounted) {
        setState(() {
          _isCalculatingDiff = false;
        });
      }
    } catch (e) {
      debugPrint('Diff error: $e');
      if (mounted) setState(() => _isCalculatingDiff = false);
    }
  }

  /// 颜色选择器
  void _pickHighlightColor() {
    Color tempColor = _highlightColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择高亮颜色'),
        backgroundColor: Colors.grey[850],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _highlightColor,
            onColorChanged: (color) => tempColor = color
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _highlightColor = tempColor);
              Navigator.pop(context);
            },
            child: const Text('确认', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  // 工具方法
  String _formatFileSize(int size) {
    if (size <= 0) return "0 B";
    const units = ["B", "KB", "MB", "GB"];
    int digitGroups = (log(size) / log(1024)).floor();
    return "${(size / pow(1024, digitGroups)).toStringAsFixed(2)} ${units[digitGroups]}";
  }

  Future<void> _deleteLeftImage() async {
    if (_isDeletingLeft) return;
    setState(() => _isDeletingLeft = true);
    try {
      await ApiService.deleteFile(widget.backendUrl, widget.image1.filePath, onDeleted: () {
        if (mounted) {
          AppNotification.show(message: '左侧图片删除成功', type: NotificationType.warning, duration: Duration(seconds: 1));
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (mounted) {
        AppNotification.show(message: '左侧图片删除失败：$e', type: NotificationType.error, duration: Duration(seconds: 3));
      }
    } finally {
      if (mounted) setState(() => _isDeletingLeft = false);
    }
  }

  Future<void> _deleteRightImage() async {
    if (_isDeletingRight) return;
    setState(() => _isDeletingRight = true);
    try {
      await ApiService.deleteFile(widget.backendUrl, widget.image2.filePath, onDeleted: () {
        if (mounted) {
          AppNotification.show(message: '右侧图片删除成功', type: NotificationType.warning, duration: Duration(seconds: 1));
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (mounted) {
        AppNotification.show(message: '右侧图片删除失败：$e', type: NotificationType.error, duration: Duration(seconds: 3));
      }
    } finally {
      if (mounted) setState(() => _isDeletingRight = false);
    }
  }

  /// 解析图片的原始数据返回结构化数据
  Map<String, dynamic> _getImageAllInfo(ui.Image image, FileRecord fileRecord) {
    Map<String, dynamic> info = {};
    try {
      // 基础信息
      info['fileName'] = fileRecord.file.split('/').last;
      info['fileSize'] = fileRecord.fileSize;
      info['formatSize'] = _formatFileSize(fileRecord.fileSize);
      info['filePath'] = fileRecord.file;

      // 图片像素信息
      info['pixelWidth'] = image.width;
      info['pixelHeight'] = image.height;
      info['aspectRatio'] = (image.width / image.height).toStringAsFixed(2);
      info['totalPixels'] = "${(image.width * image.height / 10000).toStringAsFixed(2)} 万像素";

    } catch (e) {
      info['error'] = '信息解析失败: $e';
    }
    return info;
  }

  /// 信息栏
  Widget _buildExpandableImageInfo({required Map<String, dynamic> info, required bool isLeft}) {
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
                  isLeft ? (_expandLeftInfo ? Icons.expand_less : Icons.expand_more) : (_expandRightInfo ? Icons.expand_less : Icons.expand_more),
                  color: Colors.blueAccent,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    if(isLeft) _expandLeftInfo = !_expandLeftInfo;
                    else _expandRightInfo = !_expandRightInfo;
                  });
                },
              ),
            ],
          ),

          // 高级信息
          if( (isLeft && _expandLeftInfo) || (!isLeft && _expandRightInfo) )
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片对比'),
        backgroundColor: Colors.grey[900],
        actions: [
          // 模式切换按钮
          IconButton(
            icon: Icon(
              _currentMode == CompareMode.sideBySide
                  ? Icons.layers
                  : Icons.monochrome_photos,
              color: Colors.white,
            ),
            tooltip: _currentMode == CompareMode.sideBySide
                ? '切换到重合对比'
                : '切换到两栏对比',
            onPressed: () => setState(() {
              _currentMode = _currentMode == CompareMode.sideBySide
                  ? CompareMode.overlay
                  : CompareMode.sideBySide;
            }),
          ),
        ],
      ),
      backgroundColor: Colors.grey[850],
      body: Column(
        children: [
          // 模式控制栏
          _buildModeControlBar(),
          // 对比内容区域
          Expanded(child: _buildCompareContent()),
        ],
      ),
    );
  }

  /// 构建模式控制栏
  Widget _buildModeControlBar() {
    if (_currentMode == CompareMode.sideBySide) {
      // 两栏对比控制
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
              onTap: _pickHighlightColor,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _highlightColor.withValues(alpha: _highlightOpacity),
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 透明度滑块
            Expanded(
              child: Slider(
                value: _highlightOpacity,
                min: 0.0,
                max: 1.0,
                activeColor: _highlightColor,
                inactiveColor: Colors.grey[700],
                onChanged: (value) => setState(() => _highlightOpacity = value),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(_highlightOpacity * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            // 加载状态指示器
            if (_isCalculatingDiff)
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
                icon: Icon(_showImageInfo ? Icons.info : Icons.info_outline, color: _showImageInfo ? Colors.blueAccent : Colors.white, size:20),
                tooltip: _showImageInfo ? '隐藏图片信息' : '显示图片信息',
                onPressed: ()=>setState(()=>_showImageInfo=!_showImageInfo),
              ),
            ),
          ],
        ),
      );
    } else {
      // 重合对比控制
      return Container(
        color: Colors.grey[900],
        child: Column(
          children: [
            Slider(
              value: _sliderValue,
              min: 0.0,
              max: 1.0,
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.grey[700],
              label: '左: ${((1 - _sliderValue) * 100).round()}% | 右: ${(_sliderValue * 100).round()}%',
              onChanged: (value) => setState(() => _sliderValue = value),
            ),
          ],
        ),
      );
    }
  }

  /// 构建对比内容区域
  Widget _buildCompareContent() {
    if (_uiImage1 == null || _uiImage2 == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    if (_currentMode == CompareMode.sideBySide) {
      // 两栏对比模式
      return Row(
        children: [
          // 左图
          Expanded(
            child: Stack(
              children: [
                Image(
                  image: UiImageProvider(_uiImage1!),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
                CustomPaint(
                  painter: DiffPainter(
                    diffImage: _diffImage,
                    highlightColor: _highlightColor,
                    opacity: _highlightOpacity,
                  ),
                  size: Size.infinite,
                ),
                // 左侧删除按钮
                Positioned(
                  top: 16,
                  right: 16,
                  child: _isDeletingLeft
                    ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                    : InkWell(
                      onTap: _deleteLeftImage,
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
                if(_showImageInfo)
                  Positioned(
                    left:0,
                    right:0,
                    bottom:0,
                    child: _buildExpandableImageInfo(
                      info: _leftImageDetail,
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
                Image(
                  image: UiImageProvider(_uiImage2!),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
                CustomPaint(
                  painter: DiffPainter(
                    diffImage: _diffImage,
                    highlightColor: _highlightColor,
                    opacity: _highlightOpacity,
                  ),
                  size: Size.infinite,
                ),
                // 右侧删除按钮
                Positioned(
                  top: 16,
                  right: 16,
                  child: _isDeletingRight
                    ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                    : InkWell(
                      onTap: _deleteRightImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16)
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white, size:20)
                      )
                    ),
                ),
                // 右侧可展开的图片信息栏
                if(_showImageInfo)
                  Positioned(
                    left:0,
                    right:0,
                    bottom:0,
                    child: _buildExpandableImageInfo(
                      info: _rightImageDetail, isLeft: false
                    )
                  ),
              ],
            ),
          ),
        ],
      );
    } else {
      // 重合对比模式
      final leftOpacity = 1 - _sliderValue; // 左图透明度
      final rightOpacity = _sliderValue; // 右图透明度

      return Stack(
        children: [
          // 左图-底层
          Opacity(
            opacity: leftOpacity,
            child: Image(
              image: UiImageProvider(_uiImage1!),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // 右图-上层
          Opacity(
            opacity: rightOpacity,
            child: Image(
              image: UiImageProvider(_uiImage2!),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ],
      );
    }
  }
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
  ImageStreamCompleter loadBuffer(UiImageProvider key, DecoderBufferCallback decode) {
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