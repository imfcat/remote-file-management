import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../utils/backend_provider.dart';

/// 文件请求
String fileContentUrl(BuildContext context, String windowsPath) {
  final baseUrl = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
  return '$baseUrl/file_content?file_path=${Uri.encodeComponent(windowsPath)}';
}