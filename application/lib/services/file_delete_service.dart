import 'file_record.dart';
import 'api_service.dart';

/// 删除操作结果
class FileDeleteResult {
  final List<FileRecord> currentFiles;
  final Set<String> deletedPaths;
  final Set<String> failedPaths;
  final bool verified;
  final String message;

  const FileDeleteResult({
    required this.currentFiles,
    required this.deletedPaths,
    required this.failedPaths,
    required this.verified,
    required this.message,
  });

  int get deletedCount => deletedPaths.length;
  bool get allRequestedDeleted => failedPaths.isEmpty;
}

class FileDeleteValidationException implements Exception {
  final String message;
  FileDeleteValidationException(this.message);

  @override
  String toString() => message;
}

typedef FileDeleteHandler = Future<FileDeleteResult> Function(
  List<FileRecord> targets, {
  bool resetToFirstPage,
});

/// 文件删除
class FileDeleteService {
  FileDeleteService._();

  static Set<String> pathsOf(Iterable<FileRecord> files) =>
      files.map((f) => f.filePath).toSet();

  static bool equalByPaths(List<FileRecord> a, List<FileRecord> b) {
    if (a.length != b.length) return false;
    final paths = pathsOf(a);
    if (paths.length != a.length) return false;
    for (final file in b) {
      if (!paths.contains(file.filePath)) return false;
    }
    return true;
  }

  static List<FileRecord> removeByPaths(
    List<FileRecord> source,
    Set<String> paths,
  ) =>
      source.where((f) => !paths.contains(f.filePath)).toList();

  /// 从主列表解析待删目标
  static List<FileRecord> validateTargets(
    List<FileRecord> masterList,
    List<FileRecord> targets,
  ) {
    if (targets.isEmpty) {
      throw FileDeleteValidationException('没有可删除的文件');
    }

    final masterByPath = {for (final f in masterList) f.filePath: f};
    final resolved = <FileRecord>[];
    final seen = <String>{};

    for (final target in targets) {
      final path = target.filePath.trim();
      if (path.isEmpty) {
        throw FileDeleteValidationException('存在无效的文件路径');
      }
      if (!seen.add(path)) continue;

      final master = masterByPath[path];
      if (master == null) {
        throw FileDeleteValidationException('文件不在当前目录列表中: ${target.fileName}');
      }
      resolved.add(master);
    }

    if (resolved.isEmpty) {
      throw FileDeleteValidationException('没有可删除的文件');
    }
    return resolved;
  }

  /// 更新
  static Future<FileDeleteResult> confirmDeletion({
    required String baseUrl,
    required String folder,
    required String sort,
    required String order,
    required List<FileRecord> snapshotBeforeDelete,
    required List<FileRecord> optimisticList,
    required List<String> pathsToDelete,
  }) async {
    final pathSet = pathsToDelete.toSet();
    if (pathSet.length != pathsToDelete.length) {
      return FileDeleteResult(
        currentFiles: snapshotBeforeDelete,
        deletedPaths: const {},
        failedPaths: pathSet,
        verified: false,
        message: '删除请求包含重复路径',
      );
    }

    final Map<String, dynamic> apiData;
    try {
      apiData = await ApiService.deleteFiles(baseUrl, pathsToDelete);
    } catch (e) {
      return FileDeleteResult(
        currentFiles: snapshotBeforeDelete,
        deletedPaths: const {},
        failedPaths: pathSet,
        verified: false,
        message: '删除请求失败: $e',
      );
    }

    final results = apiData['results'] as List? ?? [];
    final successPaths = <String>{};
    final failedPaths = <String>{};

    for (final path in pathSet) {
      Map<String, dynamic>? entry;
      for (final raw in results) {
        if (raw is Map && raw['file_path'] == path) {
          entry = Map<String, dynamic>.from(raw);
          break;
        }
      }
      if (entry != null && entry['success'] == true) {
        successPaths.add(path);
      } else {
        failedPaths.add(path);
      }
    }

    if (failedPaths.isNotEmpty) {
      final partialList = removeByPaths(snapshotBeforeDelete, successPaths);
      final allFailed = successPaths.isEmpty;
      return FileDeleteResult(
        currentFiles: partialList,
        deletedPaths: successPaths,
        failedPaths: failedPaths,
        verified: false,
        message: allFailed
            ? '删除失败'
            : '部分文件删除失败（${failedPaths.length} 个）',
      );
    }

    try {
      final serverList = await ApiService.listFiles(
        baseUrl: baseUrl,
        folder: folder,
        sort: sort,
        order: order,
      );

      if (equalByPaths(optimisticList, serverList)) {
        final count = successPaths.length;
        return FileDeleteResult(
          currentFiles: optimisticList,
          deletedPaths: successPaths,
          failedPaths: const {},
          verified: true,
          message: count > 1 ? '成功删除 $count 个文件' : '删除成功',
        );
      }

      return FileDeleteResult(
        currentFiles: serverList,
        deletedPaths: successPaths,
        failedPaths: const {},
        verified: false,
        message: '删除校验失败，列表已同步',
      );
    } catch (_) {
      final count = successPaths.length;
      return FileDeleteResult(
        currentFiles: optimisticList,
        deletedPaths: successPaths,
        failedPaths: const {},
        verified: true,
        message: count > 1 ? '成功删除 $count 个文件' : '删除成功',
      );
    }
  }
}
