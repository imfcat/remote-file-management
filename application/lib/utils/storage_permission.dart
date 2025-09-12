import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// 存储权限申请
Future<void> checkStoragePermission(BuildContext context) async {
  final photos = Permission.photos;
  final storage = Permission.storage;

  bool granted = false;
  if (await photos.isGranted) {
    granted = true;
  } else if (await storage.isGranted) {
    granted = true;
  } else {
    granted = (await photos.request().isGranted) || (await storage.request().isGranted);
  }

  if (!granted && context.mounted) {
    // 拒绝
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('需要存储权限'),
        content: const Text('请手动开启存储权限，否则无法正常显示图片'),
        actions: [
          TextButton(
              onPressed: () => openAppSettings(), child: const Text('去设置')),
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ],
      ),
    );
  }
}