import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../utils/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '...';
  final TextEditingController _columnController = TextEditingController(); // 弹窗输入框控制器

  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  void _showColumnEditDialog(int currentValue) {
    _columnController.text = currentValue.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改网格列数'),
        content: TextField(
          controller: _columnController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '1-8之间的数',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _columnController.clear();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final int? newValue = int.tryParse(_columnController.text);
              if (newValue == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的数字')),
                );
                return;
              }
              if (newValue < 1 || newValue > 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('列数请设置为1-8之间')),
                );
                return;
              }
              // 保存新值
              Provider.of<SettingsProvider>(context, listen: false)
                  .setGridColumnCount(newValue);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('列数设置成功')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _columnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听当前
    final currentColumnCount =
        Provider.of<SettingsProvider>(context).gridColumnCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.black87,
        toolbarHeight: 60,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 设置项列表
          Expanded(
            child: ListView(
              children: [
                // 网格列数设置项
                InkWell(
                  onTap: () => _showColumnEditDialog(currentColumnCount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '文件夹网格列数',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              currentColumnCount.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 占位
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('设置')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '其他设置项示例',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 底部版本号
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              _appVersion,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}