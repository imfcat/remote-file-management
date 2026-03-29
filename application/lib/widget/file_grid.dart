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
  String _groupBy = 'none';
  bool _isLoading = true;
  List<FileRecord> _files = [];
  Map<String, List<FileRecord>> _groupedFiles = {};
  List<String> _sortedKeys = [];
  final Set<String> _collapsedGroups = {};

  // 选择模式状态
  bool _isSelecting = false;
  final Set<FileRecord> _selectedFiles = {};
  bool _isDeleting = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool silent = false}) {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    ApiService.listFiles(
      baseUrl: url,
      folder: widget.folder,
      sort: _sort,
      order: _order,
    ).then((list) {
      if (!mounted) return;
      _files = list;
      _processData();
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppNotification.show(message: '列表加载失败: $e', type: NotificationType.error, duration: const Duration(seconds: 3));
      }
    });
  }

  void _processData() {
    // 分组逻辑
    Map<String, List<FileRecord>> tempGroup = {};
    if (_groupBy == 'type') {
      for (var f in _files) {
        tempGroup.putIfAbsent(f.mimeType.isNotEmpty ? f.mimeType : '未知类型', () => []).add(f);
      }
    } else if (_groupBy == 'folder') {
      for (var f in _files) {
        tempGroup.putIfAbsent(_getGroupFolder(f), () => []).add(f);
      }
    } else {
      tempGroup = {'全部': _files};
    }

    var tempKeys = tempGroup.keys.toList()..sort();

    setState(() {
      _groupedFiles = tempGroup;
      _sortedKeys = tempKeys;
      _isLoading = false;
    });
  }

  Future<void> reload({bool silent = false}) async {
    _load(silent: silent);
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
    if (!mounted) return;

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

      _files.removeWhere((file) => _selectedFiles.contains(file));
      _exitSelectMode();
      _processData();

      if (mounted) {
        AppNotification.show(message: '成功删除$selectedCount个文件', type: NotificationType.warning, duration: const Duration(seconds: 2));
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(message: '批量删除失败：$e（选中$selectedCount个文件）', type: NotificationType.error, duration: const Duration(seconds: 3));
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

  /// 高度计算
  double _getFastItemHeight(FileRecord f, double itemWidth) {
    final double imgWidth = f.width?.toDouble() ?? 100.0;
    final double imgHeight = f.height?.toDouble() ?? 100.0;
    if (f.fileType == 'image') {
      return itemWidth * (imgHeight / (imgWidth <= 0 ? 100.0 : imgWidth));
    }
    return itemWidth;
  }

  void _handleItemTap(FileRecord f) async {
    if (_isDeleting) return;
    if (_isSelecting) {
      _toggleFileSelection(f);
    } else {
      List<FileRecord> displayFiles = [];
      if (_groupBy == 'none') {
        displayFiles = _files;
      } else {
        for (var key in _sortedKeys) {
          displayFiles.addAll(_groupedFiles[key]!);
        }
      }

      final currentIndex = displayFiles.indexOf(f);
      final originalLength = displayFiles.length;

      final deleted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoBrowser(
            files: displayFiles,
            initialIndex: currentIndex,
          ),
        ),
      );

      if (deleted == true || displayFiles.length != originalLength) {
        if (_groupBy != 'none') {
          _files.removeWhere((item) => !displayFiles.contains(item));
        }

        reload(silent: true);
      }
    }
  }

  String _getGroupFolder(FileRecord f) {
    String path = f.file.replaceAll('\\', '/');
    String root = f.rootFolder.replaceAll('\\', '/');

    if (path.startsWith(root)) {
      String rel = path.substring(root.length);
      if (rel.startsWith('/')) rel = rel.substring(1);
      List<String> parts = rel.split('/');
      if (parts.length > 1) {
        return parts.first;
      } else {
        return '根目录';
      }
    }

    List<String> parts = path.split('/');
    if (parts.length > 2) {
      return parts[parts.length - 2];
    }
    return '根目录';
  }

  Widget _buildItemWidget(FileRecord f, SettingsProvider settings) {
    return GestureDetector(
      onTap: () => _handleItemTap(f),
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
          groupBy: _groupBy,
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
            if (deleted == true) {
              reload(silent: true);
            } else {
              _exitSelectMode();
            }
          },
          onRefresh: () => reload(silent: true),
          onSortChanged: (val) {
            final parts = val.split('-');
            setState(() {
              _sort = parts[0];
              _order = parts[1];
            });
            _load();
          },
          onGroupByChanged: (val) {
            if (_groupBy != val) {
              setState(() {
                _groupBy = val;
                _collapsedGroups.clear();
              });
              _processData();
            }
          },
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Builder(
            builder: (context) {
              List<Widget> slivers = [];

              // 预计算每个item宽度
              final screenWidth = MediaQuery.of(context).size.width;
              final padding = 8.0 * 2;
              final crossAxisSpacing = 8.0;
              final availableWidth = screenWidth - padding - (crossAxisCount - 1) * crossAxisSpacing;
              final itemWidth = availableWidth / crossAxisCount;

              for (var key in _sortedKeys) {
                final groupItems = _groupedFiles[key]!;
                List<Widget> currentGroupSlivers = [];

                final bool isCollapsed = _collapsedGroups.contains(key);

                if (_groupBy != 'none') {
                  currentGroupSlivers.add(
                    SliverToBoxAdapter(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isCollapsed) {
                              _collapsedGroups.remove(key);
                            } else {
                              _collapsedGroups.add(key);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                isCollapsed ? Icons.chevron_right : Icons.expand_more,
                                color: Colors.white70,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$key (${groupItems.length})',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (_groupBy == 'none' || !isCollapsed) {
                  // 添加网格或瀑布流列表
                  if (!settings.isWaterfallFlow) {
                    currentGroupSlivers.add(
                      SliverPadding(
                        padding: const EdgeInsets.all(8),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 1,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildItemWidget(groupItems[i], settings),
                            childCount: groupItems.length,
                          ),
                        ),
                      ),
                    );
                  } else {
                    currentGroupSlivers.add(
                      SliverPadding(
                        padding: const EdgeInsets.all(8),
                        sliver: SliverWaterfallFlow(
                          gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (_, i) {
                              final f = groupItems[i];
                              return SizedBox(
                                height: _getFastItemHeight(f, itemWidth),
                                child: _buildItemWidget(f, settings),
                              );
                            },
                            childCount: groupItems.length,
                          ),
                        ),
                      ),
                    );
                  }
                }

                slivers.add(
                  SliverMainAxisGroup(slivers: currentGroupSlivers),
                );
              }

              Widget scrollViewWidget = CustomScrollView(
                controller: _scrollController,
                cacheExtent: 500,
                slivers: slivers,
              );

              if (settings.showScrollbar) {
                return RawScrollbar(
                  controller: _scrollController,
                  interactive: true,
                  thickness: 6,
                  radius: const Radius.circular(0),
                  thumbColor: Colors.white12,
                  child: scrollViewWidget,
                );
              }

              return scrollViewWidget;
            },
          ),
        ),
      ],
    );
  }
}