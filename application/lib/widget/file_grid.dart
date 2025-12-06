import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nya_image_manage/widget/photo_browser.dart';
import 'package:provider/provider.dart';
import '../services/file_record.dart';
import '../services/api_service.dart';
import '../services/file_url.dart';
import '../utils/custom_cache.dart';
import '../utils/backend_provider.dart';

class FileGrid extends StatefulWidget {
  final String folder;
  const FileGrid({super.key, required this.folder});

  @override
  State<FileGrid> createState() => _FileGridState();
}

class _FileGridState extends State<FileGrid> {
  int _crossAxisCount = 8;
  String _sort = 'path';
  String _order = 'asc';
  late Future<List<FileRecord>> _future;
  List<FileRecord>? _files;

  // 选择模式状态
  bool _isSelecting = false;
  final Set<FileRecord> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    _future = ApiService.listFiles(
      baseUrl: url,
      folder: widget.folder,
      sort: _sort,
      order: _order,
    ).then((list) => _files = list);
  }

  /// 拉取最新列表
  Future<void> reload() async {
    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    final list = await ApiService.listFiles(
      baseUrl: url,
      folder: widget.folder,
      sort: _sort,
      order: _order,
    );
    setState(() => _files = list);
    // 重新加载时退出选择模式
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
    if (_selectedFiles.isEmpty) return;

    final int selectedCount = _selectedFiles.length;

    final confirm = await _showConfirmDialog(
      '批量删除确认',
      '是否确定删除选中的$selectedCount个文件？此操作不可恢复！',
    );

    if (!confirm) return;

    try {
      final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
      for (var file in _selectedFiles) {
        await ApiService.deleteFile(url, file.filePath);
      }

      setState(() {
        _files!.removeWhere((file) => _selectedFiles.contains(file));
        _exitSelectMode();
      });

      // 显示删除成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功删除$selectedCount个文件'),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 显示删除失败提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('批量删除失败：$e（选中$selectedCount个文件）'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
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
        if (_selectedFiles.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  /// 缩略图
  Widget _itemWidget(BuildContext context, FileRecord f) {
    Widget content;

    if (f.fileType == 'image') {
      final url = thumbUrl(context, f.file);
      content = Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
              cacheManager: customCacheManager(),
            )
          ),
        ],
      );
    } else if (f.fileType == 'video') {
      final url = thumbUrl(context, '${f.file}.jpg');
      content = Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
              cacheManager: customCacheManager(),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.videocam,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      );
    } else {
      // 非图片视频类型
      final iconMap = {
        'text': Icons.description,
      };
      content = Center(
        child: Icon(iconMap[f.fileType] ?? Icons.insert_drive_file,
            size: 48, color: Colors.white70),
      );
    }

    // 如果在选择模式中，添加选中状态指示器
    if (_isSelecting) {
      return Stack(
        children: [
          content,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _selectedFiles.contains(f)
                    ? Colors.blueAccent
                    : Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _selectedFiles.contains(f)
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
        ],
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 选择模式工具栏
        if (_isSelecting)
          Container(
            height: 60,
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text('已选择: ${_selectedFiles.length}',
                    style: const TextStyle(color: Colors.white)),
                const Spacer(),
                TextButton(
                  onPressed: _exitSelectMode,
                  child: const Text('取消', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: _deleteSelectedFiles,
                  child: const Text('删除所选', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          )
        // 普通模式工具栏
        else
          Container(
            height: 60,
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text('列数：', style: TextStyle(color: Colors.white)),
                Slider(
                  value: _crossAxisCount.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: _crossAxisCount.toString(),
                  onChanged: (v) => setState(() => _crossAxisCount = v.round()),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: '$_sort-$_order',
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'path-asc', child: Text('路径 正序')),
                    DropdownMenuItem(value: 'path-desc', child: Text('路径 倒序')),
                    DropdownMenuItem(value: 'name-asc', child: Text('名称 正序')),
                    DropdownMenuItem(value: 'name-desc', child: Text('名称 倒序')),
                    DropdownMenuItem(value: 'type-asc', child: Text('类型 正序')),
                    DropdownMenuItem(value: 'type-desc', child: Text('类型 倒序')),
                    DropdownMenuItem(value: 'size-asc', child: Text('大小 正序')),
                    DropdownMenuItem(value: 'size-desc', child: Text('大小 倒序')),
                  ],
                  onChanged: (val) {
                    final parts = val!.split('-');
                    setState(() {
                      _sort = parts[0];
                      _order = parts[1];
                      _load();
                    });
                  },
                ),
              ],
            ),
          ),

        // 网格
        Expanded(
          child: FutureBuilder<List<FileRecord>>(
            future: _future,
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final files = _files = snap.data!;
              return GridView.builder(
                padding: const EdgeInsets.all(8),
                cacheExtent: 200,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: files.length,
                itemBuilder: (_, i) {
                  final f = files[i];
                  return GestureDetector(
                    // 选择模式下点击切换选择状态，否则进入浏览
                    onTap: () async {
                      if (_isSelecting) {
                        _toggleFileSelection(f);
                      } else {
                        final deleted = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoBrowser(
                              files: files,
                              initialIndex: i,
                            ),
                          ),
                        );
                        if (deleted == true) reload();
                      }
                    },
                    // 长按进入选择模式并选中当前文件
                    onLongPress: () {
                      setState(() {
                        _isSelecting = true;
                        _selectedFiles.add(f);
                      });
                    },
                    child: Container(
                      color: Colors.grey[850],
                      child: _itemWidget(context, f),
                    ),
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