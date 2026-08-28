import 'package:flutter/foundation.dart';

class GifPlayBudget extends ChangeNotifier {
  static const int maxSlots = 24;
  static const int maxFileBytes = 16 * 1024 * 1024;

  final Set<String> _holders = {};

  bool tooLarge(int fileSize) => fileSize > maxFileBytes;

  bool isPlaying(String path) => _holders.contains(path);

  bool tryAcquire(String path, int fileSize) {
    if (tooLarge(fileSize)) return false;
    if (_holders.contains(path)) return true;
    if (_holders.length >= maxSlots) return false;
    _holders.add(path);
    return true;
  }

  void release(String path) {
    if (_holders.remove(path)) notifyListeners();
  }

  void reset() {
    if (_holders.isEmpty) return;
    _holders.clear();
    notifyListeners();
  }
}
