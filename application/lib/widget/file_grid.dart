import 'package:flutter/material.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:provider/provider.dart';
import 'package:nya_image_manage/widget/photo_browser.dart';
import '../services/file_record.dart';
import '../services/api_service.dart';
import '../utils/backend_provider.dart';
import '../utils/settings_provider.dart';
import '../screens/image_compare.dart';
import 'notification.dart';

import 'file_item.dart';
import 'file_grid_toolbar.dart';

class FileGrid extends StatefulWidget {
  final String folder;
  const FileGrid({super.key, required this.folder});

  @override
  State<FileGrid> createState() => _FileGridState();
}

class _FileGridState extends State<FileGrid> {
  String _sort = 'path';
  String _order = 'asc';
  late Future<List<FileRecord>> _future;
  List<FileRecord>? _files;

  // 选择模式状态
  bool _isSelecting = false;
  final Set<FileRecord> _selectedFiles = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    setState(() {
      _future = ApiService.listFiles(
        baseUrl: url,
        folder: widget.folder,
        sort: _sort,
        order: _order,
      ).then((list) => _files = list).catchError((e) {
        if (mounted) {
          AppNotification.show(message: '列表加载失败: $e', type: NotificationType.error, duration: const Duration(seconds: 3));
        }
        return <FileRecord>[];
      });
    });
  }

  Future<void> reload() async {
    _load();
    _exitSelectMode();
  }

  /// 确认弹窗
  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        backgroundColor: Colors.grey[850],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        contentTextStyle: const TextStyle(color: Colors.white70, fontSize: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 批量删除选中文件
  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty || _isDeleting) return;

    final int selectedCount = _selectedFiles.length;
    final confirm = await _showConfirmDialog(
      '批量删除确认',
      '是否确定删除选中的$selectedCount个文件？此操作不可恢复！',
    );

    if (!confirm) return;

    setState(() {
      _isDeleting = true;
    });

    if (mounted) {
      AppNotification.show(
        message: '正在删除 $selectedCount 个文件...',
        type: NotificationType.info,
        duration: const Duration(seconds: 10),
      );
    }

    try {
      final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;

      final filesToDelete = _selectedFiles.toList();
      for (var file in filesToDelete) {
        await ApiService.deleteFile(url, file.filePath);
      }

      setState(() {
        _files!.removeWhere((file) => _selectedFiles.contains(file));
        _exitSelectMode();
      });

      if (mounted) {
        AppNotification.show(message: '成功删除$selectedCount个文件', type: NotificationType.warning, duration: Duration(seconds: 2));
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(message: '批量删除失败：$e（选中$selectedCount个文件）', type: NotificationType.error, duration: Duration(seconds: 3));
      }
    } finally {
      // 解除锁定
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  /// 退出选择模式
  void _exitSelectMode() {
    setState(() {
      _isSelecting = false;
      _selectedFiles.clear();
    });
  }

  /// 切换文件选中状态
  void _toggleFileSelection(FileRecord file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
        // 如果取消后没有选中项，退出选择模式
        if (_selectedFiles.isEmpty) _isSelecting = false;
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  /// 判断是否选中了两张图片
  bool _isTwoImagesSelected() {
    if (_selectedFiles.length != 2) return false;
    final List<FileRecord> files = _selectedFiles.toList();
    return files[0].fileType == 'image' && files[1].fileType == 'image';
  }

  /// 计算瀑布流Item高度
  double _calculateItemHeight(BuildContext context, FileRecord f, int crossAxisCount) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 8.0 * 2;
    final crossAxisSpacing = 8.0;
    final availableWidth = screenWidth - padding - (crossAxisCount - 1) * crossAxisSpacing;
    final itemWidth = availableWidth / crossAxisCount;

    final double imgWidth = f.width?.toDouble() ?? 100.0;
    final double imgHeight = f.height?.toDouble() ?? 100.0;

    if (f.fileType == 'image') {
      return itemWidth * (imgHeight / (imgWidth == 0 ? 1.0 : imgWidth));
    } else {
      return itemWidth;
    }
  }

  void _handleItemTap(FileRecord f, int index) async {
    if (_isDeleting) return;
    if (_isSelecting) {
      _toggleFileSelection(f);
    } else {
      final originalLength = _files?.length ?? 0;
      final deleted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => PhotoBrowser(files: _files!, initialIndex: index)),
      );
      if (deleted == true || _files?.length != originalLength) reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final crossAxisCount = settings.fileListColumnCount;

    return Column(
      children: [
        FileGridToolbar(
          isSelecting: _isSelecting,
          selectedCount: _selectedFiles.length,
          showCompareButton: _isTwoImagesSelected(),
          isDeleting: _isDeleting,
          sortOption: '$_sort-$_order',
          onCancelSelect: _exitSelectMode,
          onDelete: _deleteSelectedFiles,
          onCompare: () async {
            final selectedImages = _selectedFiles.toList();
            final deleted = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ImageComparePage(
                  image1: selectedImages[0],
                  image2: selectedImages[1],
                  backendUrl: Provider.of<BackendProvider>(context, listen: false).backendUrl!,
                ),
              ),
            );
            if (deleted == true) reload(); else _exitSelectMode();
          },
          onRefresh: reload,
          onSortChanged: (val) {
            final parts = val.split('-');
            setState(() {
              _sort = parts[0];
              _order = parts[1];
              _load();
            });
          },
        ),

        Expanded(
          child: FutureBuilder<List<FileRecord>>(
            future: _future,
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final files = snap.data!;

              Widget buildItem(int i) {
                final f = files[i];
                return GestureDetector(
                  onTap: () => _handleItemTap(f, i),
                  onLongPress: () {
                    if (_isDeleting) return;
                    setState(() {
                      _isSelecting = true;
                      _selectedFiles.add(f);
                    });
                  },
                  child: FileItem(
                    file: f,
                    isSelecting: _isSelecting,
                    isSelected: _selectedFiles.contains(f),
                    isSmallThumbnail: settings.isSmallThumbnail,
                    isThumbnailCover: settings.isThumbnailCover,
                  ),
                );
              }

              if (!settings.isWaterfallFlow) {
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  cacheExtent: 200,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: files.length,
                  itemBuilder: (_, i) => buildItem(i),
                );
              }

              return WaterfallFlow.builder(
                padding: const EdgeInsets.all(8),
                cacheExtent: 200,
                gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  lastChildLayoutTypeBuilder: (index) =>
                  index == files.length ? LastChildLayoutType.foot : LastChildLayoutType.none,
                ),
                itemCount: files.length,
                itemBuilder: (_, i) {
                  final f = files[i];
                  return SizedBox(
                    height: _calculateItemHeight(context, f, crossAxisCount),
                    child: buildItem(i),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}