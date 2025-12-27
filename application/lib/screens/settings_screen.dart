import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nya_image_manage/screens/test_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../utils/settings_provider.dart';
import '../widget/notification.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum SettingItemType {
  numberInput,
  slider,
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '...';
  final TextEditingController _columnController = TextEditingController();

  int _versionTapCount = 0; // 版本号点击计数
  final int _unlockCount = 7; // 解锁需要的次数
  DateTime? _lastTapTime; // 最后一次点击时间

  // 进入测试页面
  void _handleVersionTap() {
    final now = DateTime.now();
    // 点击间隔超过1秒重置计数
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds > 1000) {
      _versionTapCount = 0;
    }
    // 更新计数和最后点击时间
    setState(() {
      _versionTapCount++;
      _lastTapTime = now;
    });

    if (_versionTapCount == _unlockCount) {
      _versionTapCount = 0;
      _lastTapTime = null;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TestPage()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }

  @override
  void dispose() {
    _columnController.dispose();
    super.dispose();
  }

  // 获取应用版本号
  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _showNumberInputDialog({
    required String title,
    required String hintText,
    required int currentValue,
    required int minValue,
    required int maxValue,
    required Function(int) onSave,
    String successMsg = '设置成功',
  }) async {
    _columnController.text = currentValue.toString();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: _columnController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        actions: [
          _buildDialogAction(
            text: '取消',
            onPressed: () {
              Navigator.pop(ctx);
              _columnController.clear();
            },
          ),
          _buildDialogAction(
            text: '确认',
            onPressed: () {
              final newValue = int.tryParse(_columnController.text);
              if (!_validateNumberInput(newValue, minValue, maxValue)) return;

              onSave(newValue!);
              Navigator.pop(ctx);
              _columnController.clear();
              _showSnackBar(successMsg);
            },
          ),
        ],
      ),
    );
  }

  // 通用滑块调节弹窗
  Future<void> _showSliderDialog({
    required String title,
    required String subTitle,
    required int currentValue,
    required int minValue,
    required int maxValue,
    required int divisions,
    required String unit,
    required Function(int) onSave,
    String successMsg = '设置成功',
  }) async {
    int tempValue = currentValue;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subTitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('当前值：'),
                    Text(
                      '$tempValue$unit',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  value: tempValue.toDouble(),
                  min: minValue.toDouble(),
                  max: maxValue.toDouble(),
                  divisions: divisions,
                  label: '$tempValue$unit',
                  onChanged: (value) => setStateDialog(() => tempValue = value.toInt()),
                ),
              ],
            ),
            actions: [
              _buildDialogAction(
                text: '取消',
                onPressed: () => Navigator.pop(ctx),
              ),
              _buildDialogAction(
                text: '确认',
                onPressed: () {
                  onSave(tempValue);
                  Navigator.pop(ctx);
                  _showSnackBar('$successMsg $tempValue$unit！');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // 通用数字输入校验
  bool _validateNumberInput(int? value, int min, int max) {
    if (value == null) {
      _showSnackBar('请输入有效的数字');
      return false;
    }
    if (value < min || value > max) {
      _showSnackBar('请输入$min-$max之间的数字');
      return false;
    }
    return true;
  }

  // 构建对话框按钮
  Widget _buildDialogAction({required String text, required VoidCallback onPressed}) {
    return TextButton(
      onPressed: onPressed,
      child: Text(text),
    );
  }

  // 显示提示消息
  void _showSnackBar(String message) {
    AppNotification.show(message: message);
  }

  // 构建可点击的设置项
  Widget _buildClickableSettingItem({
    required String title,          // 标题
    required String value,          // 当前显示值
    required SettingItemType type,  // 交互类型（数字输入/滑块）
    required int currentValue,      // 当前实际值（用于弹窗初始化）
    String? dialogTitle,            // 弹窗标题（默认使用设置项标题）
    String? hintText,               // 数字输入弹窗提示文本
    String? sliderSubTitle,         // 滑块弹窗副标题
    int minValue = 1,               // 最小值（数字/滑块通用）
    int maxValue = 100,             // 最大值（数字/滑块通用）
    int divisions = 99,             // 滑块分割数
    String unit = '',               // 单位（如%、列）
    required Function(int) onSave,  // 保存回调
    String successMsg = '设置成功',  // 成功提示语
  }) {
    void _handleTap() {
      switch (type) {
        case SettingItemType.numberInput:
          _showNumberInputDialog(
            title: dialogTitle ?? title,
            hintText: hintText ?? '$minValue-$maxValue之间的数',
            currentValue: currentValue,
            minValue: minValue,
            maxValue: maxValue,
            onSave: onSave,
            successMsg: successMsg,
          );
          break;
        case SettingItemType.slider:
          _showSliderDialog(
            title: dialogTitle ?? title,
            subTitle: sliderSubTitle ?? '',
            currentValue: currentValue,
            minValue: minValue,
            maxValue: maxValue,
            divisions: divisions,
            unit: unit,
            onSave: onSave,
            successMsg: successMsg,
          );
          break;
      }
    }

    return InkWell(
      onTap: _handleTap,
      child: _buildSettingItemContainer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: _titleTextStyle),
            Row(
              children: [
                Text(
                  value.isEmpty ? '未设置' : value,
                  style: _valueTextStyle,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建带开关的设置项
  Widget _buildSwitchSettingItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String enableMsg,
    required String disableMsg,
  }) {
    void _handleSwitchChange(bool newValue) {
      onChanged(newValue);
      _showSnackBar(newValue ? enableMsg : disableMsg);
    }

    return InkWell(
      onTap: () => _handleSwitchChange(!value),
      child: _buildSettingItemContainer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: _titleTextStyle),
            SizedBox(
              width: 40,
              height: 24,
              child: Transform.scale(
                scale: 0.8,
                alignment: Alignment.center,
                child: Switch(
                  value: value,
                  onChanged: _handleSwitchChange,
                  activeThumbColor: Colors.blue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeTrackColor: Colors.blue.withValues(alpha: 0.3),
                  inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 设置项容器
  Widget _buildSettingItemContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333), width: 0.3),
        ),
      ),
      child: child,
    );
  }

  // 标题文本样式
  final TextStyle _titleTextStyle = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  // 值文本样式
  final TextStyle _valueTextStyle = TextStyle(
    fontSize: 16,
    color: Colors.grey[600],
  );

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.black87,
        toolbarHeight: 60,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('目录页', style: TextStyle( color: Colors.grey[600])),
                ),
                _buildClickableSettingItem(
                  title: '文件夹网格列数',
                  value: settings.gridColumnCount.toString(),
                  type: SettingItemType.numberInput,
                  currentValue: settings.gridColumnCount,
                  dialogTitle: '修改网格列数',
                  hintText: '1-8之间的数',
                  minValue: 1,
                  maxValue: 8,
                  successMsg: '列数设置成功',
                  onSave: (value) => settings.setGridColumnCount(value),
                ),

                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('文件页', style: TextStyle( color: Colors.grey[600])),
                ),
                _buildClickableSettingItem(
                  title: '文件列表列数',
                  value: settings.fileListColumnCount.toString(),
                  type: SettingItemType.numberInput,
                  currentValue: settings.fileListColumnCount,
                  dialogTitle: '修改网格列数',
                  hintText: '1-20之间的数',
                  minValue: 1,
                  maxValue: 20,
                  successMsg: '列数设置成功',
                  onSave: (value) => settings.setFileListColumnCount(value),
                ),
                _buildSwitchSettingItem(
                  title: '瀑布流布局',
                  value: settings.isWaterfallFlow,
                  onChanged: settings.toggleWaterfallFlow,
                  enableMsg: '已切换到瀑布流布局',
                  disableMsg: '已切换到网格布局',
                ),
                _buildSwitchSettingItem(
                  title: '小缩略图模式',
                  value: settings.isSmallThumbnail,
                  onChanged: settings.toggleThumbnailSize,
                  enableMsg: '已切换到小缩略图',
                  disableMsg: '已切换到大缩略图',
                ),

                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('浏览页', style: TextStyle( color: Colors.grey[600])),
                ),
                _buildSwitchSettingItem(
                  title: '点击切换功能',
                  value: settings.clickToggleEnabled,
                  onChanged: settings.toggleClickEnabled,
                  enableMsg: '已开启点击切换',
                  disableMsg: '已关闭点击切换',
                ),
                _buildClickableSettingItem(
                  title: '点击区域大小',
                  value: '${settings.clickAreaSize}%',
                  type: SettingItemType.slider,
                  currentValue: settings.clickAreaSize,
                  dialogTitle: '修改点击切换区域大小',
                  sliderSubTitle: '数值为屏幕宽度的百分比',
                  minValue: 1,
                  maxValue: 100,
                  divisions: 99,
                  unit: '%',
                  successMsg: '点击区域大小已设为',
                  onSave: (value) => settings.setClickAreaSize(value),
                ),
              ],
            ),
          ),

          // 版本信息
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: InkWell(
              onTap: _handleVersionTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Text(
                _appVersion,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}