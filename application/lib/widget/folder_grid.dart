import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/settings_provider.dart';
import '../screens/file_list_screen.dart';

class FolderGrid extends StatelessWidget {
  final List<String> folders;
  const FolderGrid({super.key, required this.folders});

  @override
  Widget build(BuildContext context) {
    final columnCount = Provider.of<SettingsProvider>(context).gridColumnCount;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return Card(
          elevation: 4,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FileListScreen(folder: folder),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder, size: 64, color: Colors.amber),
                const SizedBox(height: 8),
                Text(
                  folder,
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}