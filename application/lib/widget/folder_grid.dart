import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../utils/backend_provider.dart';
import '../utils/settings_provider.dart';
import '../services/folder_record.dart';
import '../screens/file_list_screen.dart';
import '../services/api_service.dart';
import 'notification.dart';

class FolderGrid extends StatefulWidget {
  final List<Folder> folders;
  final Function(Folder, String)? onFolderMarkUpdated;

  const FolderGrid({
    super.key,
    required this.folders,
    this.onFolderMarkUpdated,
  });

  @override
  State<FolderGrid> createState() => _FolderGridState();
}

class _FolderGridState extends State<FolderGrid> {
  // 解析颜色
  Color _parseFolderColor(Folder folder) {
    if (folder.mark == null || folder.mark!.isEmpty) {
      return Colors.amber;
    }
    try {
      String colorHex = folder.mark!.replaceAll('#', '0xFF');
      return Color(int.parse(colorHex));
    } catch (e) {
      return Colors.amber;
    }
  }

  // 显示颜色选择弹窗
  void _showColorPickerDialog(BuildContext context, Folder folder) async {
    Color selectedColor = _parseFolderColor(folder);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('设置文件夹颜色'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: selectedColor,
              onColorChanged: (Color color) async {
                Navigator.pop(dialogContext);
                // 颜色转换
                String colorMark = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';

                try {
                  final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
                  await ApiService.setFolderMark(url, folder.folderName, colorMark);

                  // 更新本地UI
                  if (mounted) {
                    setState(() {
                      final folderIndex = widget.folders.indexOf(folder);
                      if (folderIndex != -1) {
                        widget.folders[folderIndex] = Folder(
                          folderName: folder.folderName,
                          count: folder.count,
                          mark: colorMark,
                          lastMtime: null,
                        );
                      }
                    });
                    AppNotification.show(message: '颜色设置成功', type: NotificationType.success);
                  }
                } catch (e) {
                  if (mounted) {
                    AppNotification.show(message: '颜色设置失败：$e', type: NotificationType.error);
                  }
                }
              },
            ),
          ),
          actions: const [],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final columnCount = Provider.of<SettingsProvider>(context).gridColumnCount;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        childAspectRatio: 1.1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: widget.folders.length,
      itemBuilder: (context, index) {
        final folder = widget.folders[index];
        final folderColor = _parseFolderColor(folder);

        return Card(
          elevation: 0,
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FileListScreen(folder: folder.folderName),
              ),
            ),
            onLongPress: () => _showColorPickerDialog(context, folder),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon( Icons.folder, size: 64, color: folderColor, ),
                Text(
                  folder.folderName,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${folder.count}项',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}