import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _cacheStoreName = 'md5_cache';
const _legacyCacheStoreName = 'thumb_cache';

String? _externalCacheDirPath;

enum ImageCacheVariant { thumb, medium, original }

/// 缓存键定义
String imageCacheKey({
  required String md5Hash,
  required ImageCacheVariant variant,
  String? pathFallback,
}) {
  final prefix = switch (variant) {
    ImageCacheVariant.thumb => 'thumb',
    ImageCacheVariant.medium => 'medium',
    ImageCacheVariant.original => 'orig',
  };
  return '${prefix}_${_stableId(md5Hash, pathFallback)}';
}

String _stableId(String md5Hash, String? pathFallback) {
  final trimmed = md5Hash.trim();
  if (trimmed.isNotEmpty && trimmed != 'unknown') {
    return trimmed;
  }
  return 'fb_${_fnv1a32(pathFallback ?? '')}';
}

String _fnv1a32(String input) {
  var hash = 2166136261;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

// 初始化缓存目录
Future<void> initCacheDir() async {
  if (_externalCacheDirPath == null) {
    final dirs = await getExternalCacheDirectories();
    if (dirs?.isNotEmpty ?? false) {
      // 取第一个缓存目录
      _externalCacheDirPath = dirs!.first.path;
    } else {
      // 外部缓存目录不可用，使用内部缓存目录
      final fallbackDir = await getTemporaryDirectory();
      _externalCacheDirPath = fallbackDir.path;
    }
  }
  await _removeLegacyThumbCache();
}

Future<void> _removeLegacyThumbCache() async {
  final root = _externalCacheDirPath;
  if (root == null) return;
  final legacy = Directory(p.join(root, _legacyCacheStoreName));
  if (await legacy.exists()) {
    try {
      await legacy.delete(recursive: true);
    } catch (_) {}
  }
}

BaseCacheManager? _instance;
BaseCacheManager customCacheManager() {
  assert(_externalCacheDirPath != null, '未初始化initCacheDir()');
  _instance ??= CacheManager(Config(
      _cacheStoreName,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 10000,
      repo: JsonCacheInfoRepository(databaseName: _cacheStoreName),
      fileSystem: IOFileSystem(p.join(
        _externalCacheDirPath!,
        _cacheStoreName,
      )),
    ));
  return _instance!;
}
