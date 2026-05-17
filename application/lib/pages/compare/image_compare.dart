import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;

import '../../services/file_url.dart';
import '../../services/file_record.dart';
import '../../utils/custom_cache.dart';
import '../../services/api_service.dart';
import '../../widget/notification.dart';

import 'compare_utils.dart';
import 'compare_toolbar.dart';
import 'side_by_side_view.dart';
import 'overlay_view.dart';

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
  Map<String, dynamic> _leftImageDetail = {}; // 左侧图片详细信息
  Map<String, dynamic> _rightImageDetail = {}; // 右侧图片详细信息

  // 缩放同步
  final TransformationController _syncTransformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    // 释放资源
    _syncTransformationController.dispose();
    _diffImage?.dispose();
    super.dispose();
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
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppNotification.show(message: '图片加载失败：$e', type: NotificationType.error, duration: const Duration(seconds: 2));
        });
      }
    }
  }

  /// 从URL加载ui.Image
  Future<ui.Image> _loadUiImageFromUrl(String url) async {
    final imageProvider = CachedNetworkImageProvider(url, cacheManager: customCacheManager());
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
        'bytes1': byteData1, 'width1': _uiImage1!.width, 'height1': _uiImage1!.height,
        'bytes2': byteData2, 'width2': _uiImage2!.width, 'height2': _uiImage2!.height,
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
      if (mounted) setState(() => _isCalculatingDiff = false);
    } catch (e) {
      debugPrint('Diff error: $e');
      if (mounted) setState(() => _isCalculatingDiff = false);
    }
  }

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
          AppNotification.show(message: '左侧图片删除成功', type: NotificationType.warning, duration: const Duration(seconds: 1));
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      if (mounted) AppNotification.show(message: '左侧图片删除失败：$e', type: NotificationType.error, duration: const Duration(seconds: 3));
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
          AppNotification.show(message: '右侧图片删除成功', type: NotificationType.warning, duration: const Duration(seconds: 1));
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      if (mounted) AppNotification.show(message: '右侧图片删除失败：$e', type: NotificationType.error, duration: const Duration(seconds: 3));
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
              _currentMode == CompareMode.sideBySide ? Icons.layers : Icons.monochrome_photos,
              color: Colors.white,
            ),
            tooltip: _currentMode == CompareMode.sideBySide ? '切换到重合对比' : '切换到两栏对比',
            onPressed: () => setState(() {
              _currentMode = _currentMode == CompareMode.sideBySide ? CompareMode.overlay : CompareMode.sideBySide;
            }),
          ),
        ],
      ),
      backgroundColor: Colors.grey[850],
      body: Column(
        children: [
          CompareToolbar(
            currentMode: _currentMode,
            highlightColor: _highlightColor,
            highlightOpacity: _highlightOpacity,
            sliderValue: _sliderValue,
            isCalculatingDiff: _isCalculatingDiff,
            showImageInfo: _showImageInfo,
            onColorChanged: (color) => setState(() => _highlightColor = color),
            onOpacityChanged: (value) => setState(() => _highlightOpacity = value),
            onSliderChanged: (value) => setState(() => _sliderValue = value),
            onResetZoom: () => _syncTransformationController.value = Matrix4.identity(),
            onToggleInfo: () => setState(() => _showImageInfo = !_showImageInfo),
          ),
          Expanded(
            child: (_uiImage1 == null || _uiImage2 == null)
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _currentMode == CompareMode.sideBySide
                ? SideBySideView(
              uiImage1: _uiImage1!,
              uiImage2: _uiImage2!,
              diffImage: _diffImage,
              highlightColor: _highlightColor,
              highlightOpacity: _highlightOpacity,
              syncTransformationController: _syncTransformationController,
              showImageInfo: _showImageInfo,
              leftImageDetail: _leftImageDetail,
              rightImageDetail: _rightImageDetail,
              isDeletingLeft: _isDeletingLeft,
              isDeletingRight: _isDeletingRight,
              onDeleteLeft: _deleteLeftImage,
              onDeleteRight: _deleteRightImage,
            )
                : OverlayView(
              uiImage1: _uiImage1!,
              uiImage2: _uiImage2!,
              sliderValue: _sliderValue,
              syncTransformationController: _syncTransformationController,
            ),
          ),
        ],
      ),
    );
  }
}