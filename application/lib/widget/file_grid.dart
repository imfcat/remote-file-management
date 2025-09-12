import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_record.dart';
import '../services/api_service.dart';
import '../services/file_url.dart';
import '../services/thumbnail_cache.dart';
import '../utils/backend_provider.dart';
import '../screens/file_browser_screen.dart';

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

  /// 删除并局部刷新
  Future<void> _deleteFile(FileRecord f) async {
    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    await ApiService.deleteFile(url, f.filePath);
    setState(() => _files!.remove(f));
  }

  /// 缩略图
  Widget _itemWidget(BuildContext context, FileRecord f) {
    if (f.fileType == 'image') {
      // 优先用本地缩略图
      return FutureBuilder<File>(
        future: ThumbnailCache.getThumbnail(f.filePath),
        builder: (_, snap) {
          if (snap.hasData && snap.data!.existsSync()) {
            return Image.file(snap.data!, fit: BoxFit.cover);
          }
          final url = fileContentUrl(context, f.filePath);
          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70),
            httpHeaders: const {"Connection": "keep-alive"},
          );
        },
      );
    }

    // 非图片
    final iconMap = {
      'video': Icons.videocam,
      'text': Icons.description,
    };
    return Center(
      child: Icon(iconMap[f.fileType] ?? Icons.insert_drive_file,
          size: 48, color: Colors.white70),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        Container(
          height: 80,
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FileBrowserScreen(files: files, initialIndex: i),
                      ),
                    ),
                    onLongPress: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('删除 ${f.fileName}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteFile(f);
                            },
                            child: const Text('删除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
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