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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    if (_isInitializing || widget.videoUrl.isEmpty) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      final videoController = VideoPlayerController.network(widget.videoUrl);
      await videoController.initialize();

      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        errorBuilder: (context, errorMessage) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                '视频加载失败\n$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );

      setState(() {
        _videoPlayerController = videoController;
        _chewieController = chewieController;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        debugPrint('视频初始化失败：$e');
      });
    }
  }

  void _disposeVideoControllers() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    _disposeVideoControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildVideoPlayer();
  }

  Widget _buildVideoPlayer() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_chewieController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.video_library_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              '无法加载视频',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Chewie(
      controller: _chewieController!,
    );
  }
}