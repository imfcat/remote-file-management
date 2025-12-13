import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/backend_provider.dart';
import '../services/api_service.dart';
import '../services/folder_record.dart';
import '../utils/storage_permission.dart';
import '../widget/folder_grid.dart';
import 'settings_screen.dart';

/// 首页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Folder> folders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    // 权限申请
    checkStoragePermission(context);
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
    final data = await ApiService.listRootFolders(url);
    final List<dynamic> foldersJson = data['folders'];
    setState(() {
      folders = foldersJson.map((json) => Folder.fromJson(json)).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('目录'),
        backgroundColor: Colors.black87,
        toolbarHeight: 60,
        leading: Icon(Icons.perm_media),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 24),
            onPressed: () {
              // 跳转到设置页面
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
          // 文件网格
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : FolderGrid(folders: folders),
          ),
        ],
      ),
    );
  }
}
