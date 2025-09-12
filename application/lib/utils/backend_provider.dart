import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackendProvider with ChangeNotifier {
  String? _backendUrl;

  String? get backendUrl => _backendUrl;

  Future<void> loadBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _backendUrl = prefs.getString('backend_url');
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', url);
    _backendUrl = url;
    notifyListeners();
  }

  bool get isConfigured => _backendUrl != null;
}