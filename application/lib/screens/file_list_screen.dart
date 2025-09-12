import 'package:flutter/material.dart';
import '../widget/file_grid.dart';

class FileListScreen extends StatelessWidget {
  final String folder;
  const FileListScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('目录: $folder'),
        backgroundColor: Colors.black87,
        toolbarHeight: 60
      ),
      body: Column(
        children: [
          // 网格
          Expanded(
            child: FileGrid(folder: folder),
          ),
        ],
      ),
    );
  }
}