import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/backend_provider.dart';
import '../services/api_service.dart';
import '../utils/storage_permission.dart';
import '../widget/folder_grid.dart';

/// 首页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> folders = [];
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
    setState(() {
      folders = List<String>.from(data['folders']);
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
        leading: Icon(Icons.perm_media)
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
