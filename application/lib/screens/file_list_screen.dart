import 'package:flutter/material.dart';
import '../widget/file_grid.dart';
import 'settings_screen.dart';

class FileListScreen extends StatelessWidget {
  final String folder;
  const FileListScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('目录: $folder'),
        backgroundColor: Colors.black87,
        toolbarHeight: 60,
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
            child: FileGrid(folder: folder),
          ),
        ],
      ),
    );
  }
}