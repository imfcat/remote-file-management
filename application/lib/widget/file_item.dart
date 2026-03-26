import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_record.dart';
import '../services/file_url.dart';
import '../utils/custom_cache.dart';
import '../utils/settings_provider.dart';

class FileItem extends StatelessWidget {
  final FileRecord file;
  final bool isSelecting;
  final bool isSelected;
  final bool isSmallThumbnail;
  final bool isThumbnailCover;

  const FileItem({
    super.key,
    required this.file,
    required this.isSelecting,
    required this.isSelected,
    required this.isSmallThumbnail,
    required this.isThumbnailCover,
  });

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  /// 根据状态获取缩略图URL
  String _getThumbnailUrl(BuildContext context) {
    final targetFile = file.fileType == 'video' || file.mimeType == 'image/gif'
        ? '${file.file}.jpg'
        : file.file;

    return isSmallThumbnail
        ? thumbUrl(context, targetFile)
        : mediumUrl(context, targetFile);
  }

  /// 文件信息叠加层
  Widget? _buildInfoOverlay(SettingsProvider settings) {
    if (!settings.showInfoTitle && !settings.showInfoSize && !settings.showInfoResolution) {
      return null;
    }

    List<Widget> infoLines = [];

    // 标题显示
    if (settings.showInfoTitle) {
      infoLines.add(Text(
        file.file,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
      ));
    }

    // 尺寸显示
    if (settings.showInfoResolution && file.width != null && file.height != null && file.width! > 0) {
      infoLines.add(Text(
        '${file.width} × ${file.height}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
      ));
    }

    // 大小显示
    if (settings.showInfoSize) {
      infoLines.add(Text(
        _formatBytes(file.fileSize),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
      ));
    }

    if (infoLines.isEmpty) return null;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(left: 6, right: 6, top: 12, bottom: 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: infoLines,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final BoxFit fitMode = isThumbnailCover ? BoxFit.cover : BoxFit.contain;
    Widget content;

    if (file.fileType == 'image' || file.fileType == 'video') {
      final url = _getThumbnailUrl(context);
      final isGif = file.mimeType == 'image/gif';
      final isVideo = file.fileType == 'video';

      content = Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: fitMode,
              placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image),
              cacheManager: customCacheManager(),
              key: ValueKey('${url}_$isSmallThumbnail'),
            ),
          ),
          if (_buildInfoOverlay(settings) != null) _buildInfoOverlay(settings)!,
          if (settings.showInfoIcon && (isGif || isVideo))
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: EdgeInsets.all(isGif ? 2 : 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isGif ? Icons.gif : Icons.videocam,
                  color: Colors.white,
                  size: isGif ? 20 : 18,
                ),
              ),
            ),
        ],
      );
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(
              file.fileType == 'text' ? Icons.description : Icons.insert_drive_file,
              size: 48,
              color: Colors.white70,
            ),
          ),
          if (_buildInfoOverlay(settings) != null) _buildInfoOverlay(settings)!,
        ],
      );
    }

    if (isSelecting) {
      content = Stack(
        children: [
          if (isSelected)
            Transform.scale(
              scale: 0.99,
              alignment: Alignment.center,
              child: Stack(
                children: [
                  content,
                  Positioned.fill(
                    child: Container(color: Colors.black.withValues(alpha: 0.3)),
                  ),
                ],
              ),
            )
          else
            content,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent : Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
            ),
          ),
        ],
      );
    }

    return Container(
      color: isThumbnailCover ? Colors.grey[850] : Colors.transparent,
      child: content,
    );
  }
}