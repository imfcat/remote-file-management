import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPreview extends StatefulWidget {
  final String videoUrl;
  const VideoPreview({super.key, required this.videoUrl});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late VideoPlayerController _vp;
  late ChewieController _cp;

  @override
  void initState() {
    super.initState();
    _vp = VideoPlayerController.network(widget.videoUrl);
    _cp = ChewieController(
      videoPlayerController: _vp,
      autoPlay: true,
      looping: false,
      showControls: true,
      allowFullScreen: true,
      allowMuting: true,
      aspectRatio: 16 / 9,
      errorBuilder: (_, err) => Center(child: Text('视频加载失败\n$err')),
    );
  }

  @override
  void dispose() {
    _cp.dispose();
    _vp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Chewie(controller: _cp);
  }
}