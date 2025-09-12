import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_record.dart';
import '../utils/backend_provider.dart';
import '../services/api_service.dart';
import '../widget/file_preview.dart';

class FileBrowserScreen extends StatefulWidget {
  final List<FileRecord> files;
  final int initialIndex;
  const FileBrowserScreen({super.key, required this.files, required this.initialIndex});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  late PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.files[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 显示
          Center(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _current = i),
              itemCount: widget.files.length,
              itemBuilder: (_, i) {
                final f = widget.files[i];
                return FilePreview(file: f);
              },
            ),
          ),
          // 工具栏
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: () => _showInfo(context, file),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () => _deleteFile(context, file),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))
        ],
      ),
    );
  }

  void _deleteFile(BuildContext context, FileRecord f) async {
    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    await ApiService.deleteFile(url, f.filePath, onDeleted: () {
      setState(() {
        widget.files.remove(f);
        if (widget.files.isEmpty) Navigator.pop(context);
      });
    });
  }
}