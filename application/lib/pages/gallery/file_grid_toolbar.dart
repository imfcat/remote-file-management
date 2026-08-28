import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../utils/settings_provider.dart';

class FileGridToolbar extends StatelessWidget {
  final bool isSelecting;
  final int selectedCount;
  final bool showCompareButton;
  final bool isDeleting;
  final String sortOption;
  final String groupBy;
  final bool areAllCollapsed;
  final int pageSize;

  final VoidCallback onToggleCollapseAll;
  final VoidCallback onCancelSelect;
  final VoidCallback onDelete;
  final VoidCallback onCompare;
  final VoidCallback onRefresh;
  final Function(String) onSortChanged;
  final Function(String) onGroupByChanged;
  final VoidCallback onFindDuplicates;
  final Function(int) onPageSizeChanged;
  final bool compact;
  final bool hasGif;
  final bool playOriginalGif;
  final VoidCallback? onTogglePlayOriginalGif;

  const FileGridToolbar({
    super.key,
    required this.isSelecting,
    required this.selectedCount,
    required this.showCompareButton,
    required this.isDeleting,
    required this.sortOption,
    required this.groupBy,
    required this.areAllCollapsed,
    required this.pageSize,
    required this.onToggleCollapseAll,
    required this.onCancelSelect,
    required this.onDelete,
    required this.onCompare,
    required this.onRefresh,
    required this.onSortChanged,
    required this.onGroupByChanged,
    required this.onFindDuplicates,
    required this.onPageSizeChanged,
    this.compact = false,
    this.hasGif = false,
    this.playOriginalGif = false,
    this.onTogglePlayOriginalGif,
  });

  List<DropdownMenuItem<int>> _buildPageSizeItems(int currentSize) {
    final List<int> presets = [1, 10, 50, 100, 500, 1000, -1];
    final List<int> options = List.from(presets);

    if (!options.contains(currentSize) && currentSize > 0) {
      options.add(currentSize);
    }

    options.sort((a, b) => a == -1 ? 1 : (b == -1 ? -1 : a.compareTo(b)));

    List<DropdownMenuItem<int>> items = options.map((val) {
      String label = val == -1 ? '全部' : '$val / 页';
      if (!presets.contains(val) && val != 0) label = '$val / 页 (自定义)';
      return DropdownMenuItem(value: val, child: Text(label));
    }).toList();

    items.add(const DropdownMenuItem(value: 0, child: Text('自定义...')));
    return items;
  }

  // 自定义数值输入框
  void _showCustomPageSizeDialog(BuildContext context, Function(int) onValidSubmit) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义分页大小'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入每页显示的数量',
          ),
          onSubmitted: (val) {
            final parsed = int.tryParse(val);
            if (parsed != null && parsed > 0) {
              Navigator.pop(context);
              onValidSubmit(parsed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed != null && parsed > 0) {
                Navigator.pop(context);
                onValidSubmit(parsed);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  // 二级设置菜单
  void _showMobileSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        String localSort = sortOption;
        String localGroup = groupBy;
        int localPageSize = pageSize;

        return StatefulBuilder(
          builder: (context, setState) {
            return Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 列数设置
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('网格列数', style: TextStyle(color: Colors.white, fontSize: 16)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: Colors.white,
                                  disabledColor: Colors.grey[700],
                                  onPressed: settings.fileListColumnCount > 1
                                      ? () => settings.setFileListColumnCount(settings.fileListColumnCount - 1)
                                      : null,
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 24),
                                  alignment: Alignment.center,
                                  child: Text(
                                      '${settings.fileListColumnCount}',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: Colors.white,
                                  disabledColor: Colors.grey[700],
                                  onPressed: settings.fileListColumnCount < 20
                                      ? () => settings.setFileListColumnCount(settings.fileListColumnCount + 1)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 分组选择
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('分组方式', style: TextStyle(color: Colors.white, fontSize: 16)),
                            DropdownButton<String>(
                              value: localGroup,
                              dropdownColor: Colors.grey[850],
                              style: const TextStyle(color: Colors.white),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'none', child: Text('无分组')),
                                DropdownMenuItem(value: 'type', child: Text('按类型')),
                                DropdownMenuItem(value: 'folder', child: Text('按目录')),
                                DropdownMenuItem(value: 'duplicate', child: Text('按重复项')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => localGroup = val);
                                  onGroupByChanged(val);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 排序选择
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('排序方式', style: TextStyle(color: Colors.white, fontSize: 16)),
                            DropdownButton<String>(
                              value: localSort,
                              dropdownColor: Colors.grey[850],
                              style: const TextStyle(color: Colors.white),
                              underline: const SizedBox(),
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
                                if (val != null) {
                                  setState(() => localSort = val);
                                  onSortChanged(val);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 分页设置
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('分页显示', style: TextStyle(color: Colors.white, fontSize: 16)),
                            DropdownButton<int>(
                              value: localPageSize,
                              dropdownColor: Colors.grey[850],
                              style: const TextStyle(color: Colors.white),
                              underline: const SizedBox(),
                              items: _buildPageSizeItems(localPageSize),
                              onChanged: (val) {
                                if (val == 0) {
                                  _showCustomPageSizeDialog(context, (newSize) {
                                    setState(() => localPageSize = newSize);
                                    onPageSizeChanged(newSize);
                                  });
                                } else if (val != null) {
                                  setState(() => localPageSize = val);
                                  onPageSizeChanged(val);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final barHeight = compact ? 44.0 : 60.0;
    final hPadding = compact ? 12.0 : 16.0;
    final actionStyle = compact
        ? const TextStyle(color: Colors.white, fontSize: 13)
        : const TextStyle(color: Colors.white);

    if (isSelecting) {
      return Container(
        height: barHeight,
        color: Colors.grey[900],
        padding: EdgeInsets.symmetric(horizontal: hPadding),
        child: Row(
          children: [
            Text(
              '已选择: $selectedCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 14 : 16,
              ),
            ),
            const Spacer(),
            if (showCompareButton)
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
                  minimumSize: Size(compact ? 48 : 64, compact ? 32 : 40),
                ),
                onPressed: isDeleting ? null : onCompare,
                child: Text('图片对比', style: TextStyle(color: Colors.blueAccent, fontSize: compact ? 13 : 14)),
              ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
                minimumSize: Size(compact ? 40 : 64, compact ? 32 : 40),
              ),
              onPressed: isDeleting ? null : onCancelSelect,
              child: Text('取消', style: actionStyle),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
                minimumSize: Size(compact ? 56 : 64, compact ? 32 : 40),
              ),
              onPressed: isDeleting ? null : onDelete,
              child: Text('删除所选', style: TextStyle(color: Colors.red, fontSize: compact ? 13 : 14)),
            ),
          ],
        ),
      );
    }

    final settings = Provider.of<SettingsProvider>(context);
    final crossAxisCount = settings.fileListColumnCount;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final iconSize = compact ? 20.0 : 24.0;

    return Container(
      height: barHeight,
      color: Colors.grey[900],
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
      child: Row(
        children: [
          if (!isMobile) ...[
            IconButton(
              icon: Icon(Icons.remove_circle_outline, size: iconSize),
              color: Colors.white,
              disabledColor: Colors.grey[700],
              tooltip: '减少列数',
              padding: EdgeInsets.all(compact ? 6 : 8),
              constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              onPressed: crossAxisCount > 1
                  ? () => settings.setFileListColumnCount(crossAxisCount - 1)
                  : null,
            ),
            Container(
              constraints: BoxConstraints(minWidth: compact ? 16 : 20),
              alignment: Alignment.center,
              child: Text(
                  '$crossAxisCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, size: iconSize),
              color: Colors.white,
              disabledColor: Colors.grey[700],
              tooltip: '增加列数',
              padding: EdgeInsets.all(compact ? 6 : 8),
              constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              onPressed: crossAxisCount < 20
                  ? () => settings.setFileListColumnCount(crossAxisCount + 1)
                  : null,
            ),
          ],

          IconButton(
            icon: Icon(settings.isWaterfallFlow ? Icons.dashboard : Icons.grid_view, color: Colors.white, size: iconSize),
            tooltip: settings.isWaterfallFlow ? '切换到网格布局' : '切换到瀑布流布局',
            padding: EdgeInsets.all(compact ? 6 : 8),
            constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
            onPressed: () => settings.toggleWaterfallFlow(!settings.isWaterfallFlow),
          ),
          IconButton(
            icon: Icon(settings.isSmallThumbnail ? Icons.zoom_out : Icons.zoom_in, color: Colors.white, size: iconSize),
            tooltip: settings.isSmallThumbnail ? '切换到大缩略图' : '切换到小缩略图',
            padding: EdgeInsets.all(compact ? 6 : 8),
            constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
            onPressed: () => settings.toggleThumbnailSize(!settings.isSmallThumbnail),
          ),
          if (hasGif)
            IconButton(
              icon: Icon(
                Icons.gif,
                color: playOriginalGif ? Colors.blue : Colors.white,
                size: iconSize,
              ),
              tooltip: playOriginalGif ? 'GIF' : 'GIF 播放',
              padding: EdgeInsets.all(compact ? 6 : 8),
              constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              onPressed: onTogglePlayOriginalGif,
            ),
          if (!settings.isWaterfallFlow)
            IconButton(
              icon: Icon(settings.isThumbnailCover ? Icons.crop : Icons.aspect_ratio, color: Colors.white, size: iconSize),
              tooltip: settings.isThumbnailCover ? '取消缩略图填充' : '开启缩略图填充',
              padding: EdgeInsets.all(compact ? 6 : 8),
              constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              onPressed: () => settings.toggleThumbnailCover(!settings.isThumbnailCover),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.info_outline, color: Colors.white, size: iconSize),
            tooltip: '信息显示设置',
            color: Colors.grey[850],
            position: PopupMenuPosition.under,
            padding: EdgeInsets.all(compact ? 6 : 8),
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
          if (!isMobile) ...[
            IconButton(
              icon: Icon(Symbols.document_search_rounded, color: Colors.white, size: iconSize),
              tooltip: '查找重复图片',
              padding: EdgeInsets.all(compact ? 6 : 8),
              constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              onPressed: onFindDuplicates,
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: pageSize,
              dropdownColor: Colors.grey[850],
              style: TextStyle(color: Colors.white, fontSize: compact ? 13 : 14),
              underline: const SizedBox(),
              items: _buildPageSizeItems(pageSize),
              onChanged: (val) {
                if (val == 0) {
                  _showCustomPageSizeDialog(context, onPageSizeChanged);
                } else if (val != null) {
                  onPageSizeChanged(val);
                }
              },
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: groupBy,
              dropdownColor: Colors.grey[850],
              style: TextStyle(color: Colors.white, fontSize: compact ? 13 : 14),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('无分组')),
                DropdownMenuItem(value: 'type', child: Text('按类型')),
                DropdownMenuItem(value: 'folder', child: Text('按目录')),
                DropdownMenuItem(value: 'duplicate', child: Text('按重复项')),
              ],
              onChanged: (val) {
                if (val != null) onGroupByChanged(val);
              },
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: sortOption,
              dropdownColor: Colors.grey[850],
              style: TextStyle(color: Colors.white, fontSize: compact ? 13 : 14),
              underline: const SizedBox(),
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
          ] else ...[
            IconButton(
              icon: Icon(Icons.tune, color: Colors.white, size: iconSize),
              tooltip: '视图与排序设置',
              padding: EdgeInsets.all(compact ? 6 : 8),
              constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              onPressed: () => _showMobileSettingsMenu(context),
            ),
          ],

          if (groupBy != 'none')
            IconButton(
              icon: Icon(areAllCollapsed ? Icons.unfold_more : Icons.unfold_less, color: Colors.white, size: iconSize),
              tooltip: areAllCollapsed ? '展开全部分组' : '折叠全部分组',
              padding: EdgeInsets.all(compact ? 6 : 8),
              constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
              onPressed: onToggleCollapseAll,
            ),

          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: iconSize),
            tooltip: '刷新文件列表',
            padding: EdgeInsets.all(compact ? 6 : 8),
            constraints: compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}