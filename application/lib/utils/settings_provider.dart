import 'package:flutter/foundation.dart';

class SettingsProvider extends ChangeNotifier {

  int _gridColumnCount = 5;
  int get gridColumnCount => _gridColumnCount;

  void setGridColumnCount(int value) {
    if (value < 1 || value > 8) return;
    _gridColumnCount = value;
    notifyListeners();
  }

  // 点击切换功能开关
  bool _clickToggleEnabled = true;
  bool get clickToggleEnabled => _clickToggleEnabled;

  // 切换点击功能开关状态
  void toggleClickEnabled(bool value) {
    _clickToggleEnabled = value;
    notifyListeners();
  }

  // 点击区域大小设置 1-100
  int _clickAreaSize = 50;
  int get clickAreaSize => _clickAreaSize;

  // 设置点击区域大小
  void setClickAreaSize(int value) {
    if (value < 1 || value > 100) return;
    _clickAreaSize = value;
    notifyListeners();
  }
}