import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StorageKeys {
  static const String gridColumnCount = 'grid_column_count';
  static const String clickToggleEnabled = 'click_toggle_enabled';
  static const String clickAreaSize = 'click_area_size';
  static const String fileListColumnCount = 'file_list_column_count';
  static const String isWaterfallFlow = 'is_waterfall_flow';
  static const String isThumbnailCover = 'is_thumbnail_cover';
  static const String isSmallThumbnail = 'is_small_thumbnail';

  static const String showInfoTitle = 'show_info_title';
  static const String showInfoSize = 'show_info_size';
  static const String showInfoResolution = 'show_info_resolution';
  static const String showInfoIcon = 'show_info_icon';
  static const String showScrollbar = 'show_scrollbar';
}

class SettingsProvider extends ChangeNotifier {
  // 默认值定义
  static const int _defaultGridColumn = 5;
  static const bool _defaultClickEnabled = true;
  static const int _defaultAreaSize = 50;
  static const int _defaultFileListColumn = 8;
  static const bool _defaultIsWaterfall = false;
  static const bool _defaultThumbnailCover = true;
  static const bool _defaultIsSmallThumb = true;

  static const bool _defaultShowTitle = false;
  static const bool _defaultShowSize = false;
  static const bool _defaultShowResolution = false;
  static const bool _defaultShowIcon = false;
  static const bool _defaultShowScrollbar = true;

  // 状态变量
  int _gridColumnCount = _defaultGridColumn;
  bool _clickToggleEnabled = _defaultClickEnabled;
  int _clickAreaSize = _defaultAreaSize;
  int _fileListColumnCount = _defaultFileListColumn;
  bool _isWaterfallFlow = _defaultIsWaterfall;
  bool _isThumbnailCover = _defaultThumbnailCover;
  bool _isSmallThumbnail = _defaultIsSmallThumb;

  bool _showInfoTitle = _defaultShowTitle;
  bool _showInfoSize = _defaultShowSize;
  bool _showInfoResolution = _defaultShowResolution;
  bool _showInfoIcon = _defaultShowIcon;
  bool _showScrollbar = _defaultShowScrollbar;

  //  getter
  int get gridColumnCount => _gridColumnCount;
  bool get clickToggleEnabled => _clickToggleEnabled;
  int get clickAreaSize => _clickAreaSize;
  int get fileListColumnCount => _fileListColumnCount;
  bool get isWaterfallFlow => _isWaterfallFlow;
  bool get isThumbnailCover => _isThumbnailCover;
  bool get isSmallThumbnail => _isSmallThumbnail;

  bool get showInfoTitle => _showInfoTitle;
  bool get showInfoSize => _showInfoSize;
  bool get showInfoResolution => _showInfoResolution;
  bool get showInfoIcon => _showInfoIcon;
  bool get showScrollbar => _showScrollbar;

  /// 初始化
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _loadFromPrefs(prefs);
    notifyListeners();
  }

  /// 加载数据
  void _loadFromPrefs(SharedPreferences prefs) {
    _gridColumnCount = prefs.getInt(_StorageKeys.gridColumnCount) ?? _defaultGridColumn;
    _clickToggleEnabled = prefs.getBool(_StorageKeys.clickToggleEnabled) ?? _defaultClickEnabled;
    _clickAreaSize = prefs.getInt(_StorageKeys.clickAreaSize) ?? _defaultAreaSize;
    _fileListColumnCount = prefs.getInt(_StorageKeys.fileListColumnCount) ?? _defaultFileListColumn;
    _isWaterfallFlow = prefs.getBool(_StorageKeys.isWaterfallFlow) ?? _defaultIsWaterfall;
    _isThumbnailCover = prefs.getBool(_StorageKeys.isThumbnailCover) ?? _defaultThumbnailCover;
    _isSmallThumbnail = prefs.getBool(_StorageKeys.isSmallThumbnail) ?? _defaultIsSmallThumb;

    _showInfoTitle = prefs.getBool(_StorageKeys.showInfoTitle) ?? _defaultShowTitle;
    _showInfoSize = prefs.getBool(_StorageKeys.showInfoSize) ?? _defaultShowSize;
    _showInfoResolution = prefs.getBool(_StorageKeys.showInfoResolution) ?? _defaultShowResolution;
    _showInfoIcon = prefs.getBool(_StorageKeys.showInfoIcon) ?? _defaultShowIcon;
    _showScrollbar = prefs.getBool(_StorageKeys.showScrollbar) ?? _defaultShowScrollbar;
  }

  /// 设置网格列数
  void setGridColumnCount(int value) {
    if (_isValidRange(value, 1, 8)) {
      _gridColumnCount = value;
      _saveInt(_StorageKeys.gridColumnCount, value);
      notifyListeners();
    }
  }

  /// 设置文件列表列数
  void setFileListColumnCount(int value) {
    if (_isValidRange(value, 1, 20)) {
      _fileListColumnCount = value;
      _saveInt(_StorageKeys.fileListColumnCount, value);
      notifyListeners();
    }
  }

  /// 切换点击切换功能
  void toggleClickEnabled(bool value) {
    _clickToggleEnabled = value;
    _saveBool(_StorageKeys.clickToggleEnabled, value);
    notifyListeners();
  }

  /// 设置点击区域大小
  void setClickAreaSize(int value) {
    if (_isValidRange(value, 1, 100)) {
      _clickAreaSize = value;
      _saveInt(_StorageKeys.clickAreaSize, value);
      notifyListeners();
    }
  }

  /// 切换瀑布流布局
  void toggleWaterfallFlow(bool value) {
    _isWaterfallFlow = value;
    _saveBool(_StorageKeys.isWaterfallFlow, value);
    notifyListeners();
  }

  /// 切换缩略图填充模式
  void toggleThumbnailCover(bool value) {
    _isThumbnailCover = value;
    _saveBool(_StorageKeys.isThumbnailCover, value);
    notifyListeners();
  }

  /// 切换缩略图尺寸
  void toggleThumbnailSize(bool value) {
    _isSmallThumbnail = value;
    _saveBool(_StorageKeys.isSmallThumbnail, value);
    notifyListeners();
  }

  /// 切换显示文件标题
  void toggleShowInfoTitle(bool value) {
    _showInfoTitle = value;
    _saveBool(_StorageKeys.showInfoTitle, value);
    notifyListeners();
  }

  /// 切换显示文件大小
  void toggleShowInfoSize(bool value) {
    _showInfoSize = value;
    _saveBool(_StorageKeys.showInfoSize, value);
    notifyListeners();
  }

  /// 切换显示文件尺寸
  void toggleShowInfoResolution(bool value) {
    _showInfoResolution = value;
    _saveBool(_StorageKeys.showInfoResolution, value);
    notifyListeners();
  }

  /// 切换显示文件图标
  void toggleShowInfoIcon(bool value) {
    _showInfoIcon = value;
    _saveBool(_StorageKeys.showInfoIcon, value);
    notifyListeners();
  }

  /// 切换滚动条显示
  void toggleShowScrollbar(bool value) {
    _showScrollbar = value;
    _saveBool(_StorageKeys.showScrollbar, value);
    notifyListeners();
  }

  // 校验数值范围
  bool _isValidRange(int value, int min, int max) {
    return value >= min && value <= max;
  }

  // 保存整数类型设置
  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  // 保存布尔类型设置
  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}