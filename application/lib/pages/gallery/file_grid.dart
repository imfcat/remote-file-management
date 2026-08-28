import 'package:flutter/material.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:provider/provider.dart';
import '../viewer/photo_browser.dart';
import '../../services/file_record.dart';
import '../../services/api_service.dart';
import '../../services/file_delete_service.dart';
import '../../utils/backend_provider.dart';
import '../../utils/settings_provider.dart';
import '../compare/image_compare.dart';
import 'widget/duplicate_finder.dart';
import '../../widget/notification.dart';

import 'file_item.dart';
import 'file_grid_toolbar.dart';

class FileGrid extends StatefulWidget {
  final String folder;
  final Function(int totalCount, int totalBytes, String typeSummary)?
  onFilesUpdated;
  const FileGrid({super.key, required this.folder, this.onFilesUpdated});

  @override
  State<FileGrid> createState() => _FileGridState();
}

class _FileGridState extends State<FileGrid> {
  String _sort = 'path';
  String _order = 'asc';
  String _groupBy = 'none';
  bool _isLoading = true;
  List<FileRecord> _files = [];
  Map<String, List<FileRecord>> _groupedFiles = {};
  List<String> _sortedKeys = [];
  final Set<String> _collapsedGroups = {};
  Map<String, List<String>>? _similarGroupPaths;

  // 分页状态
  int _currentPage = 1;

  // 选择模式状态
  bool _isSelecting = false;
  final Set<FileRecord> _selectedFiles = {};
  bool _isDeleting = false;
  int _deleteOpGeneration = 0;
  final ScrollController _scrollController = ScrollController();

  // 滚动显隐顶栏/底栏
  static const double _scrollHideThreshold = 16.0;
  static const double _scrollShowThreshold = 12.0;
  static const double _scrollJitter = 0.5;
  static const double _edgeThreshold = 8.0;
  static const double _toolbarHeight = 60.0;
  static const double _toolbarCompactHeight = 44.0;
  static const double _paginationHeight = 54.0;
  double _lastScrollOffset = 0;
  double _scrollAccum = 0;
  bool _chromeHidden = false;
  bool _showTopBar = true;
  bool _showBottomBar = true;
  bool _toolbarCompact = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final offset = position.pixels;
    final maxExtent = position.maxScrollExtent;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    if (delta.abs() < _scrollJitter) return;

    final atTop = offset <= _edgeThreshold;
    final atBottom =
        maxExtent <= _edgeThreshold || (maxExtent - offset) <= _edgeThreshold;

    var chromeHidden = _chromeHidden;
    if (atTop) {
      chromeHidden = false;
      _scrollAccum = 0;
    } else {
      if (_scrollAccum != 0 && delta.sign != _scrollAccum.sign) {
        _scrollAccum = 0;
      }
      _scrollAccum += delta;

      if (!chromeHidden && _scrollAccum > _scrollHideThreshold) {
        chromeHidden = true;
        _scrollAccum = 0;
      } else if (chromeHidden && _scrollAccum < -_scrollShowThreshold) {
        chromeHidden = false;
        _scrollAccum = 0;
      }
    }

    final showTop = !chromeHidden || _isSelecting;
    final showBottom = !chromeHidden || atBottom;
    final compact = _isSelecting && chromeHidden;

    if (chromeHidden != _chromeHidden ||
        showTop != _showTopBar ||
        showBottom != _showBottomBar ||
        compact != _toolbarCompact) {
      setState(() {
        _chromeHidden = chromeHidden;
        _showTopBar = showTop;
        _showBottomBar = showBottom;
        _toolbarCompact = compact;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _lastScrollOffset = _scrollController.offset;
        _scrollAccum = 0;
      });
    }
  }

  void _resetScrollChrome() {
    _lastScrollOffset = 0;
    _scrollAccum = 0;
    setState(() {
      _chromeHidden = false;
      _showTopBar = true;
      _showBottomBar = true;
      _toolbarCompact = false;
    });
  }

  void _syncChromeAfterSelectionChange() {
    if (!_scrollController.hasClients) {
      setState(() {
        _showTopBar = true;
        _toolbarCompact = false;
      });
      return;
    }

    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final atTop = offset <= _edgeThreshold;
    final atBottom =
        maxExtent <= _edgeThreshold || (maxExtent - offset) <= _edgeThreshold;

    setState(() {
      if (atTop) _chromeHidden = false;
      _showTopBar = !_chromeHidden || _isSelecting;
      _showBottomBar = !_chromeHidden || atBottom;
      _toolbarCompact = _isSelecting && _chromeHidden;
    });
  }

  void _load({bool silent = false}) {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    final url = Provider.of<BackendProvider>(
      context,
      listen: false,
    ).backendUrl!;
    ApiService.listFiles(
          baseUrl: url,
          folder: widget.folder,
          sort: _sort,
          order: _order,
        )
        .then((list) {
          if (!mounted) return;
          _files = list;
          _currentPage = 1;
          _processData();
          _notifyParentUpdated();
        })
        .catchError((e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            AppNotification.show(
              message: '列表加载失败: $e',
              type: NotificationType.error,
              duration: const Duration(seconds: 3),
            );
          }
        });
  }

  /// 格式化文件类型分组
  String _getTypeSummary(List<FileRecord> files) {
    if (files.isEmpty) return "无文件";
    Map<String, int> typeCounts = {};
    for (var f in files) {
      String type = f.mimeType.split('/')[1];
      if (type.isEmpty) type = 'other';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    return typeCounts.entries.map((e) => "${e.key}/${e.value}").join(", ");
  }

  /// 计算数据
  void _notifyParentUpdated() {
    if (widget.onFilesUpdated != null) {
      final int totalCount = _files.length;
      final int totalBytes = _files.fold(0, (sum, item) => sum + item.fileSize);
      final String typeSummary = _getTypeSummary(_files);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFilesUpdated!(totalCount, totalBytes, typeSummary);
      });
    }
  }

  static const String _uniquesGroupKey = '无重复';

  bool get _isSimilarSearchActive => _similarGroupPaths != null;

  void _clearSimilarSearch() {
    _similarGroupPaths = null;
  }

  Map<String, List<String>> _pathsByGroup(
    Map<String, List<FileRecord>> groupedFiles,
  ) {
    return {
      for (final entry in groupedFiles.entries)
        if (entry.key != _uniquesGroupKey)
          entry.key: entry.value.map((f) => f.filePath).toList(),
    };
  }

  Map<String, List<FileRecord>> _applySimilarGroups() {
    final groups = _similarGroupPaths!;
    final tempGroup = <String, List<FileRecord>>{};
    final used = <String>{};

    for (final entry in groups.entries) {
      final pathSet = entry.value.toSet();
      final members = _files.where((f) => pathSet.contains(f.filePath)).toList();
      if (members.length > 1) {
        tempGroup[entry.key] = members;
        used.addAll(members.map((f) => f.filePath));
      }
    }

    final uniques = _files.where((f) => !used.contains(f.filePath)).toList();
    if (uniques.isNotEmpty) {
      tempGroup[_uniquesGroupKey] = uniques;
    }
    return tempGroup;
  }

  /// 查找重复项请求
  void _findDuplicates() {
    DuplicateFinder.execute(
      context: context,
      folder: widget.folder,
      currentFiles: _files,
      onLoading: (bool isLoading) {
        setState(() {
          _isLoading = isLoading;
        });
      },
      onSuccess:
          (
            Map<String, List<FileRecord>> newGroupedFiles,
            List<String> _,
          ) {
            _similarGroupPaths = _pathsByGroup(newGroupedFiles);
            _groupBy = 'duplicate';
            _currentPage = 1;
            _processData();
          },
    );
  }

  void _processData() {
    // 分组逻辑
    Map<String, List<FileRecord>> tempGroup = {};
    if (_groupBy == 'type') {
      for (var f in _files) {
        tempGroup
            .putIfAbsent(f.mimeType.isNotEmpty ? f.mimeType : '未知类型', () => [])
            .add(f);
      }
    } else if (_groupBy == 'folder') {
      for (var f in _files) {
        tempGroup.putIfAbsent(_getGroupFolder(f), () => []).add(f);
      }
    } else if (_groupBy == 'duplicate' && _isSimilarSearchActive) {
      tempGroup = _applySimilarGroups();
    } else if (_groupBy == 'duplicate') {
      Map<String, List<FileRecord>> phashGroups = {};
      List<FileRecord> uniques = [];

      for (var f in _files) {
        if (f.phash != null && f.phash!.isNotEmpty) {
          phashGroups.putIfAbsent(f.phash!, () => []).add(f);
        } else {
          uniques.add(f);
        }
      }

      int groupCounter = 1;
      for (var entry in phashGroups.entries) {
        if (entry.value.length > 1) {
          tempGroup['重复组 $groupCounter'] = entry.value;
          groupCounter++;
        } else {
          uniques.addAll(entry.value);
        }
      }

      if (uniques.isNotEmpty) {
        tempGroup[_uniquesGroupKey] = uniques;
      }
    } else {
      tempGroup = {'全部': _files};
    }

    var tempKeys = tempGroup.keys.toList();
    if (_groupBy == 'duplicate') {
      tempKeys.sort((a, b) {
        if (a == _uniquesGroupKey) return 1;
        if (b == _uniquesGroupKey) return -1;
        int numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return numA.compareTo(numB);
      });
    } else {
      tempKeys.sort();
    }

    setState(() {
      _groupedFiles = tempGroup;
      _sortedKeys = tempKeys;
      _isLoading = false;
    });
  }

  Future<void> reload({bool silent = false}) async {
    _load(silent: silent);
    _exitSelectMode();
  }

  /// 确认弹窗
  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        backgroundColor: Colors.grey[850],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        contentTextStyle: const TextStyle(color: Colors.white70, fontSize: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 统一删除
  Future<FileDeleteResult> _deleteFiles(
    List<FileRecord> targets, {
    bool resetToFirstPage = false,
  }) async {
    if (_isDeleting) {
      return FileDeleteResult(
        currentFiles: _files,
        deletedPaths: const {},
        failedPaths: const {},
        verified: false,
        message: '正在删除中，请稍候',
      );
    }

    final url = Provider.of<BackendProvider>(
      context,
      listen: false,
    ).backendUrl!;

    List<FileRecord> validated;
    try {
      validated = FileDeleteService.validateTargets(_files, targets);
    } catch (e) {
      AppNotification.show(
        message: e.toString(),
        type: NotificationType.error,
        duration: const Duration(seconds: 3),
      );
      return FileDeleteResult(
        currentFiles: _files,
        deletedPaths: const {},
        failedPaths: const {},
        verified: false,
        message: e.toString(),
      );
    }

    final pathsToDelete = validated.map((f) => f.filePath).toList();
    final pathSet = pathsToDelete.toSet();
    final snapshot = List<FileRecord>.from(_files);
    final optimistic = FileDeleteService.removeByPaths(_files, pathSet);
    final opGen = ++_deleteOpGeneration;

    setState(() {
      _isDeleting = true;
      _files = optimistic;
      _selectedFiles.removeWhere((f) => pathSet.contains(f.filePath));
      if (_selectedFiles.isEmpty) _isSelecting = false;
      if (resetToFirstPage) {
        _currentPage = 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
          _resetScrollChrome();
        });
      }
    });
    _processData();
    _notifyParentUpdated();

    final result = await FileDeleteService.confirmDeletion(
      baseUrl: url,
      folder: widget.folder,
      sort: _sort,
      order: _order,
      snapshotBeforeDelete: snapshot,
      optimisticList: optimistic,
      pathsToDelete: pathsToDelete,
    );

    if (!mounted || opGen != _deleteOpGeneration) return result;

    setState(() {
      _isDeleting = false;
      _files = result.currentFiles;
    });
    _processData();
    _notifyParentUpdated();

    if (result.verified) {
      AppNotification.show(
        message: result.message,
        type: NotificationType.success,
        duration: const Duration(seconds: 2),
      );
    } else {
      AppNotification.show(
        message: result.message,
        type: NotificationType.error,
        duration: const Duration(seconds: 3),
      );
    }

    return result;
  }

  /// 批量删除选中文件
  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty || _isDeleting) return;

    final int selectedCount = _selectedFiles.length;
    final confirm = await _showConfirmDialog(
      '批量删除确认',
      '是否确定删除选中的$selectedCount个文件？此操作不可恢复！',
    );

    if (!confirm) return;
    if (!mounted) return;

    await _deleteFiles(_selectedFiles.toList());
    _exitSelectMode();
  }

  /// 退出选择模式
  void _exitSelectMode() {
    setState(() {
      _isSelecting = false;
      _selectedFiles.clear();
    });
    _syncChromeAfterSelectionChange();
  }

  /// 切换文件选中状态
  void _toggleFileSelection(FileRecord file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
        if (_selectedFiles.isEmpty) _isSelecting = false;
      } else {
        _selectedFiles.add(file);
      }
    });
    _syncChromeAfterSelectionChange();
  }

  /// 判断是否选中了两张图片
  bool _isTwoImagesSelected() {
    if (_selectedFiles.length != 2) return false;
    final List<FileRecord> files = _selectedFiles.toList();
    return files[0].fileType == 'image' && files[1].fileType == 'image';
  }

  /// 高度计算
  double _getFastItemHeight(FileRecord f, double itemWidth) {
    final double imgWidth = f.width?.toDouble() ?? 100.0;
    final double imgHeight = f.height?.toDouble() ?? 100.0;
    if (f.fileType == 'image') {
      return itemWidth * (imgHeight / (imgWidth <= 0 ? 100.0 : imgWidth));
    }
    return itemWidth;
  }

  String? _groupKeyOf(FileRecord file) {
    for (final key in _sortedKeys) {
      final group = _groupedFiles[key];
      if (group != null &&
          group.any((item) => item.filePath == file.filePath)) {
        return key;
      }
    }
    return null;
  }

  List<FileRecord> _viewerFilesFor(FileRecord tapped) {
    if (_groupBy == 'none') {
      return List<FileRecord>.from(_files);
    }

    if (_isSimilarSearchActive) {
      final sourceKey = _groupKeyOf(tapped);
      if (sourceKey == _uniquesGroupKey) {
        return List<FileRecord>.from(
          _groupedFiles[_uniquesGroupKey] ?? const [],
        );
      }
      final similarFiles = <FileRecord>[];
      for (final key in _sortedKeys) {
        if (key == _uniquesGroupKey) continue;
        similarFiles.addAll(_groupedFiles[key] ?? const []);
      }
      return similarFiles;
    }

    final displayFiles = <FileRecord>[];
    for (final key in _sortedKeys) {
      displayFiles.addAll(_groupedFiles[key]!);
    }
    return displayFiles;
  }

  void _handleItemTap(FileRecord f) async {
    if (_isDeleting) return;
    if (_isSelecting) {
      _toggleFileSelection(f);
      return;
    }

    final displayFiles = _viewerFilesFor(f);
    final currentIndex = displayFiles.indexWhere(
      (item) => item.filePath == f.filePath,
    );
    if (currentIndex == -1) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoBrowser(
          files: List<FileRecord>.from(displayFiles),
          initialIndex: currentIndex,
          onDeleteFiles: _deleteFiles,
        ),
      ),
    );
  }

  String _getGroupFolder(FileRecord f) {
    String path = f.file.replaceAll('\\', '/');
    String root = f.rootFolder.replaceAll('\\', '/');

    if (path.startsWith(root)) {
      String rel = path.substring(root.length);
      if (rel.startsWith('/')) rel = rel.substring(1);
      List<String> parts = rel.split('/');
      if (parts.length > 1) {
        return parts.first;
      } else {
        return '根目录';
      }
    }

    List<String> parts = path.split('/');
    if (parts.length > 2) {
      return parts[parts.length - 2];
    }
    return '根目录';
  }

  Widget _buildItemWidget(FileRecord f, SettingsProvider settings) {
    return GestureDetector(
      onTap: () => _handleItemTap(f),
      onLongPress: () {
        if (_isDeleting) return;
        setState(() {
          _isSelecting = true;
          _selectedFiles.add(f);
        });
        _syncChromeAfterSelectionChange();
      },
      child: FileItem(
        file: f,
        isSelecting: _isSelecting,
        isSelected: _selectedFiles.contains(f),
        isSmallThumbnail: settings.isSmallThumbnail,
        isThumbnailCover: settings.isThumbnailCover,
      ),
    );
  }

  /// 更改分页大小逻辑
  void _handlePageSizeChanged(int newSize, SettingsProvider settings) {
    if (_groupBy != 'none') {
      settings.setPageSizeGrouped(newSize);
    } else {
      settings.setPageSizePure(newSize);
    }
    setState(() => _currentPage = 1);
    _resetScrollChrome();
  }

  Widget _buildToolbar({
    required bool areAllCollapsed,
    required int pageSize,
    required List<String> displayKeys,
    required SettingsProvider settings,
  }) {
    return FileGridToolbar(
      compact: _toolbarCompact,
      isSelecting: _isSelecting,
      selectedCount: _selectedFiles.length,
      showCompareButton: _isTwoImagesSelected(),
      isDeleting: _isDeleting,
      sortOption: '$_sort-$_order',
      groupBy: _groupBy,
      areAllCollapsed: areAllCollapsed,
      pageSize: pageSize,
      onToggleCollapseAll: () {
        setState(() {
          if (areAllCollapsed) {
            _collapsedGroups.removeAll(displayKeys);
          } else {
            _collapsedGroups.addAll(displayKeys);
          }
        });
      },
      onCancelSelect: _exitSelectMode,
      onDelete: _deleteSelectedFiles,
      onCompare: () async {
        final selectedImages = _selectedFiles.toList();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageComparePage(
              image1: selectedImages[0],
              image2: selectedImages[1],
              onDeleteFiles: _deleteFiles,
            ),
          ),
        );
        _exitSelectMode();
      },
      onRefresh: () => reload(silent: true),
      onSortChanged: (val) {
        final parts = val.split('-');
        setState(() {
          _sort = parts[0];
          _order = parts[1];
          _currentPage = 1;
        });
        _load();
      },
      onFindDuplicates: _findDuplicates,
      onGroupByChanged: (val) {
        if (_groupBy != val) {
          setState(() {
            _groupBy = val;
            _collapsedGroups.clear();
            _currentPage = 1;
            if (val != 'duplicate') _clearSimilarSearch();
          });
          _processData();
        }
      },
      onPageSizeChanged: (newSize) => _handlePageSizeChanged(newSize, settings),
    );
  }

  Widget _buildAnimatedTopBar(Widget toolbar) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: _showTopBar ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _showTopBar ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_showTopBar,
          child: Material(
            elevation: 4,
            color: Colors.transparent,
            child: toolbar,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBottomBar(Widget paginationBar) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: _showBottomBar ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _showBottomBar ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_showBottomBar,
          child: Material(
            elevation: 4,
            color: Colors.transparent,
            child: paginationBar,
          ),
        ),
      ),
    );
  }

  /// 构建动态页码控制器
  Widget _buildPaginationBar(int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();

    Set<int> pagesToShow = {};
    pagesToShow.add(1);
    pagesToShow.add(totalPages);
    pagesToShow.add(_currentPage);

    if (_currentPage > 1) pagesToShow.add(_currentPage - 1);
    if (_currentPage > 2) pagesToShow.add(_currentPage - 2);
    if (_currentPage > 3) pagesToShow.add(_currentPage - 3);
    if (_currentPage < totalPages) pagesToShow.add(_currentPage + 1);
    if (_currentPage < totalPages - 1) pagesToShow.add(_currentPage + 2);
    if (_currentPage < totalPages - 2) pagesToShow.add(_currentPage + 3);

    List<int> sortedPages = pagesToShow.toList()..sort();
    List<Widget> pageWidgets = [];

    for (int i = 0; i < sortedPages.length; i++) {
      int page = sortedPages[i];

      if (i > 0 && page - sortedPages[i - 1] > 1) {
        pageWidgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '...',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
        );
      }

      final bool isCurrent = page == _currentPage;
      pageWidgets.add(
        InkWell(
          onTap: isCurrent
              ? null
              : () {
                  setState(() => _currentPage = page);
                  _scrollController.jumpTo(0);
                  _resetScrollChrome();
                },
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.blueAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCurrent ? Colors.blueAccent : Colors.white24,
                width: 1,
              ),
            ),
            child: Text(
              '$page',
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(top: BorderSide(color: Colors.black45, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一页',
            color: _currentPage > 1 ? Colors.white : Colors.white30,
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _scrollController.jumpTo(0);
                    _resetScrollChrome();
                  }
                : null,
          ),

          // 滚动显示的页码按钮排
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(mainAxisSize: MainAxisSize.min, children: pageWidgets),
            ),
          ),

          // 下一页
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一页',
            color: _currentPage < totalPages ? Colors.white : Colors.white30,
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() => _currentPage++);
                    _scrollController.jumpTo(0);
                    _resetScrollChrome();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final crossAxisCount = settings.fileListColumnCount;

    // 分页计算
    final bool isGrouped = _groupBy != 'none';
    final int pageSize = isGrouped
        ? settings.pageSizeGrouped
        : settings.pageSizePure;
    final int totalItems = isGrouped ? _sortedKeys.length : _files.length;
    final int totalPages = pageSize <= 0 || totalItems == 0
        ? 1
        : (totalItems / pageSize).ceil();

    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }

    List<String> displayKeys = [];
    Map<String, List<FileRecord>> displayGroups = {};

    if (!isGrouped) {
      displayKeys = ['全部'];
      if (pageSize <= 0) {
        displayGroups = {'全部': _files};
      } else {
        final start = (_currentPage - 1) * pageSize;
        displayGroups = {'全部': _files.skip(start).take(pageSize).toList()};
      }
    } else {
      if (pageSize <= 0) {
        displayKeys = _sortedKeys;
      } else {
        final start = (_currentPage - 1) * pageSize;
        displayKeys = _sortedKeys.skip(start).take(pageSize).toList();
      }
      displayGroups = _groupedFiles;
    }

    final bool areAllCollapsed =
        displayKeys.isNotEmpty &&
        _collapsedGroups.containsAll(displayKeys) &&
        displayKeys.length ==
            _collapsedGroups.intersection(displayKeys.toSet()).length;

    final toolbar = _buildToolbar(
      areAllCollapsed: areAllCollapsed,
      pageSize: pageSize,
      displayKeys: displayKeys,
      settings: settings,
    );
    final paginationBar = _buildPaginationBar(totalPages);
    final topInset = _showTopBar
        ? (_toolbarCompact ? _toolbarCompactHeight : _toolbarHeight)
        : 0.0;
    final bottomInset = (!_isLoading && totalPages > 1 && _showBottomBar)
        ? _paginationHeight
        : 0.0;

    return Stack(
      children: [
        Positioned.fill(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Builder(
                  builder: (context) {
                    List<Widget> slivers = [];

                    final screenWidth = MediaQuery.of(context).size.width;
                    final padding = 8.0 * 2;
                    final crossAxisSpacing = 8.0;
                    final availableWidth =
                        screenWidth -
                        padding -
                        (crossAxisCount - 1) * crossAxisSpacing;
                    final itemWidth = availableWidth / crossAxisCount;

                    for (var key in displayKeys) {
                      final groupItems = displayGroups[key]!;
                      List<Widget> currentGroupSlivers = [];

                      final bool isCollapsed = _collapsedGroups.contains(key);

                      if (_groupBy != 'none') {
                        currentGroupSlivers.add(
                          SliverToBoxAdapter(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isCollapsed) {
                                    _collapsedGroups.remove(key);
                                  } else {
                                    _collapsedGroups.add(key);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isCollapsed
                                          ? Icons.chevron_right
                                          : Icons.expand_more,
                                      color: Colors.white70,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$key (${groupItems.length})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      if (_groupBy == 'none' || !isCollapsed) {
                        if (!settings.isWaterfallFlow) {
                          currentGroupSlivers.add(
                            SliverPadding(
                              padding: const EdgeInsets.all(8),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: 1,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) =>
                                      _buildItemWidget(groupItems[i], settings),
                                  childCount: groupItems.length,
                                ),
                              ),
                            ),
                          );
                        } else {
                          currentGroupSlivers.add(
                            SliverPadding(
                              padding: const EdgeInsets.all(8),
                              sliver: SliverWaterfallFlow(
                                gridDelegate:
                                    SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 8.0,
                                      mainAxisSpacing: 8.0,
                                    ),
                                delegate: SliverChildBuilderDelegate((_, i) {
                                  final f = groupItems[i];
                                  return SizedBox(
                                    height: _getFastItemHeight(f, itemWidth),
                                    child: _buildItemWidget(f, settings),
                                  );
                                }, childCount: groupItems.length),
                              ),
                            ),
                          );
                        }
                      }

                      slivers.add(
                        SliverMainAxisGroup(slivers: currentGroupSlivers),
                      );
                    }

                    Widget scrollViewWidget = AnimatedPadding(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(
                        top: topInset,
                        bottom: bottomInset,
                      ),
                      child: CustomScrollView(
                        controller: _scrollController,
                        cacheExtent: 500,
                        slivers: slivers,
                      ),
                    );

                    if (settings.showScrollbar) {
                      return RawScrollbar(
                        controller: _scrollController,
                        interactive: true,
                        thickness: 6,
                        radius: const Radius.circular(0),
                        thumbColor: Colors.white12,
                        child: scrollViewWidget,
                      );
                    }

                    return scrollViewWidget;
                  },
                ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildAnimatedTopBar(toolbar),
        ),

        if (!_isLoading && totalPages > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildAnimatedBottomBar(paginationBar),
          ),
      ],
    );
  }
}