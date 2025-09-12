import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/file_record.dart';
import '../services/file_url.dart';

class FilePreview extends StatelessWidget {
  final FileRecord file;
  const FilePreview({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final url = fileContentUrl(context, file.filePath);

    switch (file.fileType) {
      case 'image':
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
          httpHeaders: const {"Connection": "keep-alive"},
        );

      case 'video':
      // todo: 播放器
        return const Center(child: Icon(Icons.videocam, size: 64));

      case 'text':
        return FutureBuilder<String>(
          future: DefaultAssetBundle.of(context).loadString(file.filePath),   // 本地读取即可
          builder: (_, snap) => snap.hasData
              ? SingleChildScrollView(child: SelectableText(snap.data!))
              : const Center(child: CircularProgressIndicator()),
        );

      default:
        return Center(child: Text('无法预览\n${file.fileName}', textAlign: TextAlign.center));
    }
  }
}