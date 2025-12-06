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
  final TextEditingController _areaSizeController = TextEditingController(); // 区域大小输入控制器

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

  // 显示区域大小设置对话框
  void _showAreaSizeEditDialog(int currentValue) {
    int _tempValue = currentValue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            title: const Text('修改点击切换区域大小'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '数值为屏幕宽度的百分比，建议设置20-80%',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('区域大小：'),
                    Text(
                      '$_tempValue%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _tempValue.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '$_tempValue%',
                  onChanged: (double value) {
                    setStateDialog(() {
                      _tempValue = value.toInt();
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Provider.of<SettingsProvider>(context, listen: false)
                      .setClickAreaSize(_tempValue);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('点击区域大小已设为 $_tempValue%！')),
                  );
                },
                child: const Text('确认'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _columnController.dispose();
    _areaSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听当前
    final currentColumnCount = Provider.of<SettingsProvider>(context).gridColumnCount;
    final clickToggleEnabled = Provider.of<SettingsProvider>(context).clickToggleEnabled;
    final clickAreaSize = Provider.of<SettingsProvider>(context).clickAreaSize;

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
                // 点击切换开关选项
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '启用点击切换功能',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: clickToggleEnabled,
                        onChanged: (value) {
                          Provider.of<SettingsProvider>(context, listen: false)
                              .toggleClickEnabled(value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  value ? '已开启点击切换' : '已关闭点击切换'
                              ),
                            ),
                          );
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
                // 点击区域大小设置项
                InkWell(
                  onTap: () => _showAreaSizeEditDialog(clickAreaSize),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '点击区域大小',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${clickAreaSize} %',
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