import 'package:flutter/material.dart';
import 'file_grid.dart';
import '../settings/settings_screen.dart';

class FileListScreen extends StatefulWidget {
  final String folder;
  const FileListScreen({super.key, required this.folder});

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  int _totalCount = 0;
  int _totalBytes = 0;
  String _typeSummary = "...";

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return "${count.toStringAsFixed(2)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        toolbarHeight: 60,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '目录: ${widget.folder}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '文件: $_totalCount/${_formatFileSize(_totalBytes)}  类型: $_typeSummary',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: '设置',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 网格
          Expanded(
            child: FileGrid(
              folder: widget.folder,
              onFilesUpdated: (totalCount, totalBytes, typeSummary) {
                setState(() {
                  _totalCount = totalCount;
                  _totalBytes = totalBytes;
                  _typeSummary = typeSummary;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}