import 'package:flutter/foundation.dart';

class SettingsProvider extends ChangeNotifier {

  int _gridColumnCount = 5;
  int get gridColumnCount => _gridColumnCount;

  void setGridColumnCount(int value) {
    if (value < 1 || value > 8) return;
    _gridColumnCount = value;
    notifyListeners();
  }
}