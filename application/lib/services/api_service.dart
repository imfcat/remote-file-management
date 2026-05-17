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
    String? folder,
    String? sort,
    String? order,
    bool isDeleted = false,
  }) async {
    final queryParams = <String, dynamic>{};
    if (folder != null && folder.isNotEmpty) queryParams['folder'] = folder;
    if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;
    if (order != null && order.isNotEmpty) queryParams['order'] = order;
    if (isDeleted) queryParams['is_deleted'] = 'true';

    final uri = Uri.parse('$baseUrl/list_files').replace(queryParameters: queryParams);
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

  static Future<void> restoreFile(
      String baseUrl,
      String filePath, {
        VoidCallback? onRestored,
      }) async {
    final uri = Uri.parse('$baseUrl/restore_file')
        .replace(queryParameters: {'file_path': filePath});
    final res = await http.post(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      final msg = res.body.isNotEmpty ? res.body : '恢复接口 ${res.statusCode}';
      throw Exception(msg);
    }
    onRestored?.call();
  }

  static Future<Map<String, dynamic>> calculatePhash(
      String baseUrl, String folder) async {
    final uri = Uri.parse('$baseUrl/calculate_phash').replace(queryParameters: {
      'folder': folder,
    });
    final res = await http.post(uri).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('失败: ${res.statusCode}');
  }

  static Future<Map<String, dynamic>> checkPhashStatus(
      String baseUrl, String folder) async {
    final uri = Uri.parse('$baseUrl/phash_status').replace(queryParameters: {
      'folder': folder,
    });
    final res = await getWithTimeout(uri, timeout: _timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('获取计算状态失败');
  }

  static Future<List<List<FileRecord>>> findSimilarImages(
      String baseUrl, String folder, int distance) async {
    final uri = Uri.parse('$baseUrl/find_similar_images').replace(queryParameters: {
      'folder': folder,
      'distance': distance.toString(),
    });
    final res = await getWithTimeout(uri, timeout: const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List<dynamic> groupsData = data['groups'] ?? [];

      List<List<FileRecord>> parsedGroups = [];
      for (var group in groupsData) {
        if (group is List) {
          parsedGroups.add(group.map((e) => FileRecord.fromJson(e)).toList());
        }
      }
      return parsedGroups;
    }
    throw Exception('查找相似图片失败: ${res.statusCode}');
  }

  static Future<void> setFolderMark(
      String baseUrl,
      String folder,
      String mark
      ) async {
    final uri = Uri.parse('$baseUrl/folder_mark').replace(queryParameters: {
      'folder': folder,
      'mark': mark,
    });
    final res = await getWithTimeout(uri, timeout: _timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('标记文件夹失败');
  }
}