import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../utils/backend_provider.dart';

/// 文件请求
String fileContentUrl(BuildContext context, String path) {
  final base = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
  return '$base/file_content?file_path=${Uri.encodeComponent(path)}';
}

/// 缩略图
String thumbUrl(BuildContext context, String path) {
  final base = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
  return '$base/file_content?file_path=/.cache/thumb/${Uri.encodeComponent(path)}';
}

/// 大缩略图
String mediumUrl(BuildContext context, String path) {
  final base = Provider.of<BackendProvider>(context, listen: false).backendUrl!;
  return '$base/file_content?file_path=/.cache/medium/${Uri.encodeComponent(path)}';
}