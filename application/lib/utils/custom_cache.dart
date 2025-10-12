import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String? _externalCacheDirPath;

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
}

BaseCacheManager customCacheManager() {
  assert(_externalCacheDirPath != null, '未初始化initCacheDir()');

  return CacheManager(
    Config(
      'thumb_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 10000,
      repo: JsonCacheInfoRepository(databaseName: 'thumb_cache'),
      fileSystem: IOFileSystem(p.join(
        _externalCacheDirPath!,
        'thumb_cache',
      )),
    ),
  );
}
