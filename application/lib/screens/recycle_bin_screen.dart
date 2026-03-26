import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import '../services/api_service.dart';
import '../services/file_record.dart';
import '../utils/backend_provider.dart';
import '../utils/settings_provider.dart';
import '../widget/file_item.dart';
import '../widget/notification.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  late Future<List<FileRecord>> _future;
  List<FileRecord>? _files;
  final Set<FileRecord> _selectedFiles = {};

  bool _isSelecting = false;
  bool _isRestoring = false;

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
        isDeleted: true,
      ).then((list) => _files = list).catchError((e) {
        if (mounted) {
          AppNotification.show(message: '回收站加载失败: $e', type: NotificationType.error);
        }
        return <FileRecord>[];
      });
    });
  }

  Future<void> _restoreSelectedFiles() async {
    if (_selectedFiles.isEmpty || _isRestoring) return;

    setState(() => _isRestoring = true);
    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    final filesToRestore = _selectedFiles.toList();
    int successCount = 0;

    for (var file in filesToRestore) {
      try {
        await ApiService.restoreFile(url, file.filePath);
        successCount++;
        _files?.remove(file);
      } catch (e) {
        if (mounted) {
          AppNotification.show(message: '恢复失败：${file.fileName}', type: NotificationType.error);
        }
      }
    }

    if (mounted) {
      AppNotification.show(
          message: '成功恢复 $successCount 个文件',
          type: NotificationType.success
      );
      setState(() {
        _isSelecting = false;
        _selectedFiles.clear();
        _isRestoring = false;
      });
    }
  }

  double _calculateItemHeight(BuildContext context, FileRecord f, int crossAxisCount) {
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 16.0;
    const crossAxisSpacing = 8.0;
    final availableWidth = screenWidth - padding - (crossAxisCount - 1) * crossAxisSpacing;
    final itemWidth = availableWidth / crossAxisCount;

    final double imgWidth = f.width?.toDouble() ?? 100.0;
    final double imgHeight = f.height?.toDouble() ?? 100.0;

    return f.fileType == 'image'
        ? itemWidth * (imgHeight / (imgWidth == 0 ? 1.0 : imgWidth))
        : itemWidth;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final crossAxisCount = settings.fileListColumnCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelecting ? '已选 ${_selectedFiles.length} 项' : '回收站'),
        backgroundColor: Colors.black87,
        leading: _isSelecting
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isSelecting = false;
            _selectedFiles.clear();
          }),
        )
            : const BackButton(),
        actions: [
          if (_isSelecting)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedFiles.length == _files?.length) {
                    _selectedFiles.clear();
                  } else {
                    _selectedFiles.addAll(_files ?? []);
                  }
                });
              },
              child: Text(
                _selectedFiles.length == _files?.length ? '取消全选' : '全选',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<FileRecord>>(
              future: _future,
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final files = snap.data!;

                if (files.isEmpty) {
                  return const Center(
                    child: Text('回收站为空', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                Widget buildItem(int i) {
                  final f = files[i];
                  return GestureDetector(
                    onTap: () {
                      if (_isSelecting) {
                        setState(() {
                          _selectedFiles.contains(f) ? _selectedFiles.remove(f) : _selectedFiles.add(f);
                          if (_selectedFiles.isEmpty) _isSelecting = false;
                        });
                      }
                    },
                    onLongPress: () {
                      if (!_isSelecting) {
                        setState(() {
                          _isSelecting = true;
                          _selectedFiles.add(f);
                        });
                      }
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

                return settings.isWaterfallFlow
                    ? WaterfallFlow.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemCount: files.length,
                  itemBuilder: (_, i) => SizedBox(
                    height: _calculateItemHeight(context, files[i], crossAxisCount),
                    child: buildItem(i),
                  ),
                )
                    : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: files.length,
                  itemBuilder: (_, i) => buildItem(i),
                );
              },
            ),
          ),
          // 底部恢复操作栏
          if (_isSelecting)
            Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isRestoring ? null : _restoreSelectedFiles,
                      icon: _isRestoring
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.restore),
                      label: Text(_isRestoring ? '恢复中...' : '恢复选中'),
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}