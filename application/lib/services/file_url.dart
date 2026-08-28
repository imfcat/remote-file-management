import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../utils/backend_provider.dart';
import '../utils/custom_cache.dart';
import 'file_record.dart';

class CachedMediaRequest {
  final String url;
  final String cacheKey;

  const CachedMediaRequest({required this.url, required this.cacheKey});
}

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

String _coverPath(FileRecord file) {
  final isGif = file.mimeType == 'image/gif';
  if (file.fileType == 'video' || isGif) {
    return '${file.file}.jpg';
  }
  return file.file;
}

String _keyFor(FileRecord file, ImageCacheVariant variant) {
  return imageCacheKey(
    md5Hash: file.md5Hash,
    variant: variant,
    pathFallback: file.file,
  );
}

CachedMediaRequest originalMedia(BuildContext context, FileRecord file) {
  return CachedMediaRequest(
    url: fileContentUrl(context, file.file),
    cacheKey: _keyFor(file, ImageCacheVariant.original),
  );
}

CachedMediaRequest thumbMedia(BuildContext context, FileRecord file) {
  return CachedMediaRequest(
    url: thumbUrl(context, _coverPath(file)),
    cacheKey: _keyFor(file, ImageCacheVariant.thumb),
  );
}

CachedMediaRequest mediumMedia(BuildContext context, FileRecord file) {
  return CachedMediaRequest(
    url: mediumUrl(context, _coverPath(file)),
    cacheKey: _keyFor(file, ImageCacheVariant.medium),
  );
}
