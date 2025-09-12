import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;

import 'file_record.dart';
import 'timeout_client.dart';

class ApiService {
  /// 加载超时
  static const _timeout = Duration(seconds: 5);

  static Future<Map<String, dynamic>> listRootFolders(String baseUrl) async {
    final uri = Uri.parse('$baseUrl/list_root_folders');
    final res = await getWithTimeout(uri, timeout: _timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('文件夹加载失败');
  }

  static Future<List<FileRecord>> listFiles({
    required String baseUrl,
    required String folder,
    required String sort,
    required String order,
  }) async {
    final uri = Uri.parse('$baseUrl/list_files').replace(queryParameters: {
      'folder': folder,
      'sort': sort,
      'order': order,
    });
    final res = await getWithTimeout(uri, timeout: _timeout);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body)['files'];
      return data.map((e) => FileRecord.fromJson(e)).toList();
    }
    throw Exception('文件列表加载失败');
  }

  static Future<void> deleteFile(
      String baseUrl,
      String filePath, {
        VoidCallback? onDeleted,
      }) async {
    final uri = Uri.parse('$baseUrl/delete_file')
        .replace(queryParameters: {'file_path': filePath});
    final res = await http.delete(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = res.body.isNotEmpty ? res.body : '删除接口 ${res.statusCode}';
      throw Exception(msg);
    }
    onDeleted?.call();
  }
}