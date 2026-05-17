import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nya_image_manage/services/api_service.dart';
import 'package:nya_image_manage/services/file_record.dart';
import 'package:nya_image_manage/utils/backend_provider.dart';
import 'package:nya_image_manage/widget/notification.dart';

class DuplicateFinder {
  static Future<void> execute({
    required BuildContext context,
    required String folder,
    required List<FileRecord> currentFiles,
    required Function(bool isLoading) onLoading,
    required Function(Map<String, List<FileRecord>> groupedFiles, List<String> sortedKeys) onSuccess,
  }) async {
    final url = Provider.of<BackendProvider>(context, listen: false).backendUrl!;

    int? selectedDistance = await _showDistanceDialog(context);
    if (selectedDistance == null) return;

    onLoading(true);

    try {
      AppNotification.show(message: '正在检查并计算特征库...', type: NotificationType.info);
      final res = await ApiService.calculatePhash(url, folder);
      final status = res['status'];

      if (status == 'started' || status == 'running') {
        AppNotification.show(
            message: '后台正在提取图片特征，请稍候...',
            type: NotificationType.info,
            duration: const Duration(seconds: 3)
        );

        bool isCompleted = false;
        while (!isCompleted && context.mounted) {
          await Future.delayed(const Duration(seconds: 2));
          if (!context.mounted) break;

          try {
            final checkRes = await ApiService.checkPhashStatus(url, folder);
            isCompleted = checkRes['is_completed'] ?? false;

            if (!isCompleted) {
              final remaining = checkRes['remaining'] ?? 0;
              debugPrint('特征计算中，剩余: $remaining 张');
            }
          } catch (e) {
            debugPrint('轮询状态错误: $e');
          }
        }
      }

      if (!context.mounted) return;
      AppNotification.show(message: '特征提取完毕，正在比对相似度...', type: NotificationType.info);

      List<List<FileRecord>> similarGroups = await ApiService.findSimilarImages(url, folder, selectedDistance);

      if (similarGroups.isEmpty) {
        AppNotification.show(message: '未发现相似图片', type: NotificationType.warning);
        return;
      }

      _processGroupData(similarGroups, currentFiles, onSuccess);
      AppNotification.show(message: '比对完成', type: NotificationType.success);

    } catch (e) {
      AppNotification.show(message: '查找重复项出错: $e', type: NotificationType.error);
    } finally {
      if (context.mounted) {
        onLoading(false);
      }
    }
  }

  /// 处理分组数据
  static void _processGroupData(
      List<List<FileRecord>> similarGroups,
      List<FileRecord> currentFiles,
      Function(Map<String, List<FileRecord>> groupedFiles, List<String> sortedKeys) onSuccess) {

    Map<String, List<FileRecord>> tempGroup = {};
    List<FileRecord> duplicatesList = [];

    int counter = 1;
    for (var group in similarGroups) {
      tempGroup['相似组 $counter'] = group;
      duplicatesList.addAll(group);
      counter++;
    }

    List<FileRecord> uniques = currentFiles.where(
            (f) => !duplicatesList.any((dup) => dup.filePath == f.filePath)
    ).toList();

    if (uniques.isNotEmpty) {
      tempGroup['无重复'] = uniques;
    }

    var tempKeys = tempGroup.keys.toList();
    tempKeys.sort((a, b) {
      if (a == '无重复') return 1;
      if (b == '无重复') return -1;
      int numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });

    onSuccess(tempGroup, tempKeys);
  }

  /// 距离选择弹窗
  static Future<int?> _showDistanceDialog(BuildContext context) async {
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        int distanceValue = 5;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('查找相似图片', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('容错度 (汉明距离): $distanceValue', style: const TextStyle(color: Colors.white70)),
                  Slider(
                    value: distanceValue.toDouble(),
                    min: 0,
                    max: 15,
                    divisions: 15,
                    label: distanceValue.toString(),
                    onChanged: (double value) {
                      setState(() {
                        distanceValue = value.toInt();
                      });
                    },
                  ),
                  const Text('提示: 0 为完全相同，5 为略有差异(如裁剪/水印)，10 以上可能找出无关图片。',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, distanceValue),
                  child: const Text('开始查找', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}