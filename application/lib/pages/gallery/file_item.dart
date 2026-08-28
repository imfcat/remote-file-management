import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/file_record.dart';
import '../../services/file_url.dart';
import '../../utils/custom_cache.dart';
import '../../utils/settings_provider.dart';
import 'gif_play_budget.dart';

class FileItem extends StatefulWidget {
  final FileRecord file;
  final bool isSelecting;
  final bool isSelected;
  final bool isSmallThumbnail;
  final bool isThumbnailCover;
  final bool playOriginalGif;
  final int? thumbnailCacheWidth;
  final GifPlayBudget? gifPlayBudget;

  const FileItem({
    super.key,
    required this.file,
    required this.isSelecting,
    required this.isSelected,
    required this.isSmallThumbnail,
    required this.isThumbnailCover,
    this.playOriginalGif = false,
    this.thumbnailCacheWidth,
    this.gifPlayBudget,
  });

  @override
  State<FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
  bool _holdingSlot = false;

  bool get _isGif => widget.file.mimeType == 'image/gif';

  bool get _playGif => widget.playOriginalGif && _isGif && _holdingSlot;

  @override
  void initState() {
    super.initState();
    widget.gifPlayBudget?.addListener(_onBudgetChanged);
    _tryAcquire();
  }

  @override
  void didUpdateWidget(FileItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gifPlayBudget != widget.gifPlayBudget) {
      oldWidget.gifPlayBudget?.removeListener(_onBudgetChanged);
      widget.gifPlayBudget?.addListener(_onBudgetChanged);
    }

    final pathChanged = oldWidget.file.filePath != widget.file.filePath;
    final playChanged = oldWidget.playOriginalGif != widget.playOriginalGif;
    if (pathChanged || playChanged) {
      if (_holdingSlot) {
        oldWidget.gifPlayBudget?.release(oldWidget.file.filePath);
        _holdingSlot = false;
      }
      _tryAcquire();
    }
  }

  @override
  void dispose() {
    widget.gifPlayBudget?.removeListener(_onBudgetChanged);
    if (_holdingSlot) {
      widget.gifPlayBudget?.release(widget.file.filePath);
    }
    super.dispose();
  }

  void _onBudgetChanged() {
    if (!mounted || _holdingSlot || !widget.playOriginalGif || !_isGif) return;
    if (_tryAcquire()) setState(() {});
  }

  bool _tryAcquire() {
    final budget = widget.gifPlayBudget;
    if (budget == null || !widget.playOriginalGif || !_isGif) {
      _holdingSlot = false;
      return false;
    }
    _holdingSlot = budget.tryAcquire(widget.file.filePath, widget.file.fileSize);
    return _holdingSlot;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  /// 根据状态获取缩略图URL
  String _getThumbnailUrl(BuildContext context) {
    final targetFile = widget.file.fileType == 'video' || _isGif
        ? '${widget.file.file}.jpg'
        : widget.file.file;

    return widget.isSmallThumbnail
        ? thumbUrl(context, targetFile)
        : mediumUrl(context, targetFile);
  }

  /// 文件信息叠加层
  Widget? _buildInfoOverlay(SettingsProvider settings) {
    if (!settings.showInfoTitle &&
        !settings.showInfoSize &&
        !settings.showInfoResolution) {
      return null;
    }

    List<Widget> infoLines = [];

    // 标题显示
    if (settings.showInfoTitle) {
      infoLines.add(Text(
        widget.file.file,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
      ));
    }

    // 尺寸显示
    if (settings.showInfoResolution &&
        widget.file.width != null &&
        widget.file.height != null &&
        widget.file.width! > 0) {
      infoLines.add(Text(
        '${widget.file.width} × ${widget.file.height}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
      ));
    }

    // 大小显示
    if (settings.showInfoSize) {
      infoLines.add(Text(
        _formatBytes(widget.file.fileSize),
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
    final BoxFit fitMode = widget.isThumbnailCover ? BoxFit.cover : BoxFit.contain;
    Widget content;

    if (widget.file.fileType == 'image' || widget.file.fileType == 'video') {
      final url = _playGif
          ? fileContentUrl(context, widget.file.file)
          : _getThumbnailUrl(context);
      final isVideo = widget.file.fileType == 'video';

      content = Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: fitMode,
              memCacheWidth: _playGif ? widget.thumbnailCacheWidth : null,
              placeholder: (_, _) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image),
              cacheManager: customCacheManager(),
              key: ValueKey('${url}_${widget.isSmallThumbnail}_$_playGif'),
            ),
          ),
          if (_buildInfoOverlay(settings) != null) _buildInfoOverlay(settings)!,
          if (settings.showInfoIcon && (_isGif || isVideo))
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: EdgeInsets.all(_isGif ? 2 : 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _isGif ? Icons.gif : Icons.videocam,
                  color: Colors.white,
                  size: _isGif ? 20 : 18,
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
              widget.file.fileType == 'text'
                  ? Icons.description
                  : Icons.insert_drive_file,
              size: 48,
              color: Colors.white70,
            ),
          ),
          if (_buildInfoOverlay(settings) != null) _buildInfoOverlay(settings)!,
        ],
      );
    }

    if (widget.isSelecting) {
      content = Stack(
        children: [
          if (widget.isSelected)
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
                color: widget.isSelected ? Colors.blueAccent : Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: widget.isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
        ],
      );
    }

    return Container(
      color: widget.isThumbnailCover ? Colors.grey[850] : Colors.transparent,
      child: content,
    );
  }
}