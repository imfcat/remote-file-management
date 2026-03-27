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

class _FolderGridState extends State<FolderGrid> with SingleTickerProviderStateMixin {

  String? _flashingFolder;
  late AnimationController _flashController;
  late Animation<Color?> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flashAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.white24,
    ).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _highlightFolder(String folderName) {
    setState(() {
      _flashingFolder = folderName;
    });

    _flashController.repeat(reverse: true);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _flashingFolder == folderName) {
        _flashController.stop();
        _flashController.reset();
        setState(() {
          _flashingFolder = null;
        });
      }
    });
  }

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
                String colorMark = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

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

        return AnimatedBuilder(
          animation: _flashController,
          builder: (context, child) {
            final isFlashing = _flashingFolder == folder.folderName;
            return Card(
              elevation: 0,
              color: isFlashing ? _flashAnimation.value : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: child,
            );
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FileListScreen(folder: folder.folderName),
                ),
              );
              if (mounted) {
                _highlightFolder(folder.folderName);
              }
            },
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