import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nya_image_manage/widget/video_preview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import '../services/file_record.dart';
import '../services/file_url.dart';
import '../services/api_service.dart';
import '../utils/backend_provider.dart';
import '../utils/custom_cache.dart';

class PhotoBrowser extends StatefulWidget {
  final List<FileRecord> files;
  final int initialIndex;
  const PhotoBrowser({super.key, required this.files, required this.initialIndex});

  @override
  State<PhotoBrowser> createState() => _PhotoBrowserState();
}

enum SlideDirection { forward, backward, none }

class _PhotoBrowserState extends State<PhotoBrowser> {
  late PageController _controller;
  int _current = 0;
  bool _uiVisible = true;
  bool _hasDeleted = false;
  SlideDirection _lastDirection = SlideDirection.none;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
    WidgetsBinding.instance.addPostFrameCallback((_) => _preload(_current));
  }

  void _preload(int current) async {
    final urls = widget.files.map((f) => mediumUrl(context, f.file)).toList();
    final List<int> cacheOrder = [];
    cacheOrder.add(current);
    // 缓存后n张
    for (int i = 1; i <= 10; i++) {
      final nextIndex = current + i;
      if (nextIndex < urls.length) {
        cacheOrder.add(nextIndex);
      }
    }
    // 缓存前n张
    for (int i = 1; i <= 10; i++) {
      final prevIndex = current - i;
      if (prevIndex >= 0) {
        cacheOrder.add(prevIndex);
      }
    }
    // 执行缓存操作
    for (final index in cacheOrder) {
      final url = urls[index];
      // 检查是否已缓存
      final fileInfo = await customCacheManager().getFileFromCache(url);
      if (fileInfo == null) {
        customCacheManager().getFileStream(url);
      }
    }
  }

  void _toggleUi() => setState(() => _uiVisible = !_uiVisible);

  /// 二次确认删除
  Future<void> _deleteFile(FileRecord f) async {
    final bool? confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 60,
              right: 10,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 300),
                child: AlertDialog(
                  insetPadding: EdgeInsets.zero,
                  actionsPadding: EdgeInsets.zero,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '确认删除',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('删除', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('删除 ${f.fileName}？'),
                    ],
                  ),
                  actions: const [],
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    await ApiService.deleteFile(url, f.filePath, onDeleted: () {
      setState(() {
        widget.files.remove(f);
        _hasDeleted = true;
        if (widget.files.isEmpty) {
          Navigator.pop(context, true);
          return;
        }
        // 根据最后滑动方向计算跳转页码
        int targetPage;
        if (_lastDirection == SlideDirection.backward) {
          targetPage = _current.clamp(0, widget.files.length - 1);
        } else if (_lastDirection == SlideDirection.forward) {
          targetPage = (_current - 1).clamp(0, widget.files.length - 1);
        } else {
          targetPage = (_current - 1).clamp(0, widget.files.length - 1);
        }
        _current = targetPage;
        _controller.jumpToPage(targetPage);
      });
    });
  }

  /// 字节计算
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.files.length;
    final cf = widget.files[_current];
    final shadows = <Shadow>[
      Shadow(
        offset: Offset(1.0, 1.0),
        blurRadius: 3.0,
        color: Color.fromARGB(255, 0, 0, 0),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: _toggleUi,
            child: PhotoViewGallery.builder(
              itemCount: total,
              pageController: _controller,
              onPageChanged: (i) {
                // 判断滑动方向
                if (i > _current) {
                  _lastDirection = SlideDirection.backward;
                } else if (i < _current) {
                  _lastDirection = SlideDirection.forward;
                }
                setState(() => _current = i);
                _preload(i);
              },
              builder: (_, index) {
                final f = widget.files[index];
                // 图片
                if (f.fileType == 'image') {
                  final url = mediumUrl(context, f.file);
                  return PhotoViewGalleryPageOptions(
                    imageProvider: CachedNetworkImageProvider(
                      url,
                      cacheManager: customCacheManager(),
                    ),
                    minScale: PhotoViewComputedScale.contained * 0.5,
                    maxScale: PhotoViewComputedScale.covered * 4.0,
                  );
                }

                // 视频
                final url = fileContentUrl(context, f.file);
                return PhotoViewGalleryPageOptions.customChild(
                  child: VideoPreview(videoUrl: url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.contained,
                );
              },
              loadingBuilder: (_, __) => const Center(child: CircularProgressIndicator()),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _uiVisible ? 0 : -60,
            left: 0, right: 0, height: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context, _hasDeleted),
                      ),
                      Text(cf.fileName, style: TextStyle(fontSize: 18, shadows: shadows)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cf.width}x${cf.height}\n${_formatBytes(cf.fileSize)}',
                        style: TextStyle(color: Colors.white70, fontSize: 14, shadows: shadows),
                        textAlign: TextAlign.right
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${_current + 1} / $total',
                        style: TextStyle(color: Colors.white70, fontSize: 14, shadows: shadows),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        onPressed: () => _showInfo(context, cf),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: () => _deleteFile(cf),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, FileRecord f) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(f.fileName),
        content: Text('路径：${f.filePath}\n大小：${f.fileSize} bytes\n尺寸：${f.width}x${f.height}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }
}