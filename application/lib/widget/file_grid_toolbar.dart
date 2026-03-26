import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/settings_provider.dart';

class FileGridToolbar extends StatelessWidget {
  final bool isSelecting;
  final int selectedCount;
  final bool showCompareButton;
  final bool isDeleting;
  final String sortOption;
  final VoidCallback onCancelSelect;
  final VoidCallback onDelete;
  final VoidCallback onCompare;
  final VoidCallback onRefresh;
  final Function(String) onSortChanged;

  const FileGridToolbar({
    super.key,
    required this.isSelecting,
    required this.selectedCount,
    required this.showCompareButton,
    required this.isDeleting,
    required this.sortOption,
    required this.onCancelSelect,
    required this.onDelete,
    required this.onCompare,
    required this.onRefresh,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelecting) {
      return Container(
        height: 60,
        color: Colors.grey[900],
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Text('已选择: $selectedCount', style: const TextStyle(color: Colors.white)),
            const Spacer(),
            if (showCompareButton)
              TextButton(
                onPressed: isDeleting ? null : onCompare,
                child: const Text('图片对比', style: TextStyle(color: Colors.blueAccent)),
              ),
            TextButton(
              onPressed: isDeleting ? null : onCancelSelect,
              child: const Text('取消', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: isDeleting ? null : onDelete,
              child: const Text('删除所选', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    final settings = Provider.of<SettingsProvider>(context);
    final crossAxisCount = settings.fileListColumnCount;

    return Container(
      height: 60,
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // 列数显示
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.white,
            disabledColor: Colors.grey[700],
            tooltip: '减少列数',
            onPressed: crossAxisCount > 1
                ? () => settings.setFileListColumnCount(crossAxisCount - 1)
                : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.center,
            child: Text(
                '$crossAxisCount',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: Colors.white,
            disabledColor: Colors.grey[700],
            tooltip: '增加列数',
            onPressed: crossAxisCount < 20
                ? () => settings.setFileListColumnCount(crossAxisCount + 1)
                : null,
          ),
          // 布局切换按钮
          IconButton(
            icon: Icon(settings.isWaterfallFlow ? Icons.dashboard : Icons.grid_view, color: Colors.white),
            tooltip: settings.isWaterfallFlow ? '切换到网格布局' : '切换到瀑布流布局',
            onPressed: () => settings.toggleWaterfallFlow(!settings.isWaterfallFlow),
          ),
          // 缩略图尺寸切换按钮
          IconButton(
            icon: Icon(settings.isSmallThumbnail ? Icons.zoom_out : Icons.zoom_in, color: Colors.white),
            tooltip: settings.isSmallThumbnail ? '切换到大缩略图' : '切换到小缩略图',
            onPressed: () => settings.toggleThumbnailSize(!settings.isSmallThumbnail),
          ),
          if (!settings.isWaterfallFlow)
            IconButton(
              icon: Icon(settings.isThumbnailCover ? Icons.crop : Icons.aspect_ratio, color: Colors.white),
              tooltip: settings.isThumbnailCover ? '取消缩略图填充' : '开启缩略图填充',
              onPressed: () => settings.toggleThumbnailCover(!settings.isThumbnailCover),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: '信息显示设置',
            color: Colors.grey[850],
            position: PopupMenuPosition.under,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(checked: settings.showInfoTitle, value: 'title', child: const Text('标题显示', style: TextStyle(color: Colors.white))),
              CheckedPopupMenuItem(checked: settings.showInfoSize, value: 'size', child: const Text('大小显示', style: TextStyle(color: Colors.white))),
              CheckedPopupMenuItem(checked: settings.showInfoResolution, value: 'resolution', child: const Text('尺寸显示', style: TextStyle(color: Colors.white))),
              CheckedPopupMenuItem(checked: settings.showInfoIcon, value: 'icon', child: const Text('角标显示', style: TextStyle(color: Colors.white))),
            ],
            onSelected: (val) {
              if (val == 'title') settings.toggleShowInfoTitle(!settings.showInfoTitle);
              if (val == 'size') settings.toggleShowInfoSize(!settings.showInfoSize);
              if (val == 'resolution') settings.toggleShowInfoResolution(!settings.showInfoResolution);
              if (val == 'icon') settings.toggleShowInfoIcon(!settings.showInfoIcon);
            },
          ),
          const Spacer(),
          DropdownButton<String>(
            value: sortOption,
            dropdownColor: Colors.grey[850],
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'path-asc', child: Text('路径 正序')),
              DropdownMenuItem(value: 'path-desc', child: Text('路径 倒序')),
              DropdownMenuItem(value: 'name-asc', child: Text('名称 正序')),
              DropdownMenuItem(value: 'name-desc', child: Text('名称 倒序')),
              DropdownMenuItem(value: 'type-asc', child: Text('类型 正序')),
              DropdownMenuItem(value: 'type-desc', child: Text('类型 倒序')),
              DropdownMenuItem(value: 'size-asc', child: Text('大小 正序')),
              DropdownMenuItem(value: 'size-desc', child: Text('大小 倒序')),
            ],
            onChanged: (val) {
              if (val != null) onSortChanged(val);
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '刷新文件列表',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}