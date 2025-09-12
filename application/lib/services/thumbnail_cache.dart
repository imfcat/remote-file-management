import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class ThumbnailCache {
  static Directory? _thumbDir;

  /// 初始化缓存目录并清理过期文件
  static Future<void> init() async {
    final doc = await getApplicationDocumentsDirectory();
    _thumbDir = Directory(p.join(doc.path, 'thumb_cache'));
    if (!await _thumbDir!.exists()) await _thumbDir!.create(recursive: true);
    _cleanExpired();
  }

  /// 生成或获取缩略图文件
  static Future<File> getThumbnail(String originalPath) async {
    final name = '${md5.convert(originalPath.codeUnits)}.jpg';
    final thumbFile = File(p.join(_thumbDir!.path, name));
    if (await thumbFile.exists()) {
      await thumbFile.setLastAccessed(DateTime.now());
      return thumbFile;
    }

    final bytes = await compute(_decodeAndResize, originalPath);
    await thumbFile.writeAsBytes(bytes);
    return thumbFile;
  }

  static Uint8List _decodeAndResize(String path) {
    final imgBytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(imgBytes);
    if (decoded == null) throw Exception('decode fail');
    final resized = img.copyResize(decoded, width: 200);
    return img.encodeJpg(resized, quality: 85);
  }

  /// 清理 10 天未访问的缩略图
  static Future<void> _cleanExpired() async {
    final now = DateTime.now();
    await for (var f in _thumbDir!.list()) {
      if (f is File) {
        final last = await f.lastAccessed();
        if (now.difference(last).inDays > 10) await f.delete();
      }
    }
  }
}