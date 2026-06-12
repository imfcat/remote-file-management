import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nya_image_manage/pages/viewer/video_preview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import '../../services/file_record.dart';
import '../../services/file_delete_service.dart';
import '../../services/file_url.dart';
import '../../utils/custom_cache.dart';
import '../../utils/settings_provider.dart';
import '../../widget/notification.dart';

class PhotoBrowser extends StatefulWidget {
  final List<FileRecord> files;
  final int initialIndex;
  final FileDeleteHandler onDeleteFiles;

  const PhotoBrowser({
    super.key,
    required this.files,
    required this.initialIndex,
    required this.onDeleteFiles,
  });

  @override
  State<PhotoBrowser> createState() => _PhotoBrowserState();
}

enum SlideDirection { forward, backward, none }

class _PhotoBrowserState extends State<PhotoBrowser> {
  late PageController _controller;
  int _current = 0;
  bool _uiVisible = true;
  bool _hasDeleted = false;
  bool _showOriginal = false;
  bool _isDeleting = false;
  SlideDirection _lastDirection = SlideDirection.none;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
    WidgetsBinding.instance.addPostFrameCallback((_) => _preload(_current));
  }

  void _preload(int current) async {
    final List<int> cacheOrder = [current];
    final total = widget.files.length;

    for (int i = 1; i <= 3; i++) {
      if (current + i < total) cacheOrder.add(current + i);
    }
    for (int i = 1; i <= 3; i++) {
      if (current - i >= 0) cacheOrder.add(current - i);
    }
    for (final index in cacheOrder) {
      final url = mediumUrl(context, widget.files[index].file);
      final fileInfo = await customCacheManager().getFileFromCache(url);
      if (fileInfo == null) {
        customCacheManager().getFileStream(url);
      }
    }
  }

  void _toggleUi() => setState(() => _uiVisible = !_uiVisible);

  int _indexOfPath(String path) =>
      widget.files.indexWhere((item) => item.filePath == path);

  void _applyLocalRemove(int originalIndex) {
    setState(() {
      widget.files.removeAt(originalIndex);
      _hasDeleted = true;

      if (widget.files.isEmpty) {
        return;
      }

      int targetPage;
      if (_lastDirection == SlideDirection.backward) {
        targetPage = _current.clamp(0, widget.files.length - 1);
      } else if (_lastDirection == SlideDirection.forward) {
        targetPage = (_current - 1).clamp(0, widget.files.length - 1);
      } else {
        targetPage = _current.clamp(0, widget.files.length - 1);
      }
      _current = targetPage;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.jumpToPage(_current);
        }
      });
    });
  }

  void _rollbackLocalInsert(int originalIndex, FileRecord file) {
    setState(() {
      final insertIndex = originalIndex.clamp(0, widget.files.length);
      widget.files.insert(insertIndex, file);
      _current = insertIndex;
      _hasDeleted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.jumpToPage(_current);
        }
      });
    });
  }

  /// 二次确认删除
  Future<void> _deleteFile(FileRecord f) async {
    if (_isDeleting) return;

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
    if (!mounted) return;

    final path = f.filePath;
    final originalIndex = _indexOfPath(path);
    if (originalIndex == -1) return;

    setState(() => _isDeleting = true);
    _applyLocalRemove(originalIndex);

    final result = await widget.onDeleteFiles([f]);
    if (!mounted) return;

    setState(() => _isDeleting = false);

    if (!result.deletedPaths.contains(path)) {
      if (widget.files.isEmpty || _indexOfPath(path) == -1) {
        _rollbackLocalInsert(originalIndex, f);
      }
      return;
    }

    if (!result.verified) {
      final serverPaths = FileDeleteService.pathsOf(result.currentFiles);
      if (serverPaths.contains(path) && _indexOfPath(path) == -1) {
        _rollbackLocalInsert(originalIndex, f);
      }
    }

    if (widget.files.isEmpty && mounted) {
      Navigator.pop(context, true);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  void _toggleOriginalWithSnackBar() {
    setState(() {
      _showOriginal = !_showOriginal;
    });
    AppNotification.show(message: _showOriginal ? '已切换为原图显示' : '已切换为压缩图显示');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    final total = widget.files.length;
    final cf = widget.files[_current];
    final shadows = <Shadow>[
      Shadow(
        offset: Offset(1.0, 1.0),
        blurRadius: 3.0,
        color: Color.fromARGB(255, 0, 0, 0),
      ),
    ];

    void prevPage() {
      if (_current > 0) {
        setState(() {
          _lastDirection = SlideDirection.forward;
          _current--;
        });
        _controller.animateToPage(
          _current,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _preload(_current);
      }
    }

    void nextPage() {
      if (_current < total - 1) {
        setState(() {
          _lastDirection = SlideDirection.backward;
          _current++;
        });
        _controller.animateToPage(
          _current,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _preload(_current);
      }
    }

    final settings = Provider.of<SettingsProvider>(context);
    final clickToggleEnabled = settings.clickToggleEnabled;
    final clickAreaSize = settings.clickAreaSize;
    final screenWidth = MediaQuery.of(context).size.width;
    final clickAreaActualWidth = screenWidth * (clickAreaSize / 100) / 2;

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
                if (f.fileType == 'image') {
                  final url = f.mimeType == 'image/gif'
                      ? fileContentUrl(context, f.file)
                      : (_showOriginal
                        ? fileContentUrl(context, f.file)
                        : mediumUrl(context, f.file));
                  return PhotoViewGalleryPageOptions(
                    imageProvider: CachedNetworkImageProvider(
                      url,
                      cacheManager: customCacheManager(),
                    ),
                    minScale: PhotoViewComputedScale.contained * 0.5,
                    maxScale: PhotoViewComputedScale.covered * 4.0,
                  );
                }

                final url = fileContentUrl(context, f.file);
                return PhotoViewGalleryPageOptions.customChild(
                  child: VideoPreview(
                    videoUrl: url,
                    uiVisible: _uiVisible,
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.contained,
                );
              },
              loadingBuilder: (_, _) => const Center(child: CircularProgressIndicator()),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
          if (clickToggleEnabled)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: clickAreaActualWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: prevPage,
              ),
            ),
          if (clickToggleEnabled)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: clickAreaActualWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: nextPage,
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
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white, shadows: shadows),
                          onPressed: () => Navigator.pop(context, _hasDeleted),
                        ),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cf.fileName,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, shadows: shadows, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                '${_formatBytes(cf.fileSize)}  (${cf.width}x${cf.height})',
                                style: TextStyle(color: Colors.white70, fontSize: 12, shadows: shadows),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_current + 1} / $total',
                        style: TextStyle(color: Colors.white70, fontSize: 14, shadows: shadows),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.info_outline, color: Colors.white, shadows: shadows),
                        onPressed: () => _showInfo(context, cf),
                      ),
                      if (!(cf.fileType == 'video' || cf.mimeType == 'image/gif'))
                      IconButton(
                        icon: Icon(
                          _showOriginal ? Icons.image : Icons.image_outlined,
                          color: _showOriginal ? Colors.blue : Colors.white, shadows: shadows
                        ),
                        onPressed: _toggleOriginalWithSnackBar,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.white, shadows: shadows),
                        onPressed: _isDeleting ? null : () => _deleteFile(cf),
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
        content: Text('路径：${f.filePath}\n大小：${f.fileSize} bytes\n尺寸：${f.width}x${f.height}\n校验：${f.md5Hash}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }
}
