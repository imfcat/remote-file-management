import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreview extends StatefulWidget {
  final String videoUrl;
  final bool uiVisible;

  const VideoPreview({
    super.key,
    required this.videoUrl,
    required this.uiVisible,
  });

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _videoPlayerController;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      _isInitializing = false;
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_isInitializing || widget.videoUrl.isEmpty) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      final videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await videoController.initialize();

      videoController.addListener(() {
        if (mounted) setState(() {});
      });

      setState(() {
        _videoPlayerController = videoController;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        debugPrint('视频初始化失败：$e');
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.video_library_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text('无法加载视频', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // 视频画面
        AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: VideoPlayer(_videoPlayerController!),
        ),

        // 播放控件
        AnimatedOpacity(
          opacity: widget.uiVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !widget.uiVisible,
            child: GestureDetector(
              onTap: () {
                if (_videoPlayerController!.value.isPlaying) {
                  _videoPlayerController!.pause();
                } else {
                  _videoPlayerController!.play();
                }
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(
                  _videoPlayerController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),

        // 进度条
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: widget.uiVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !widget.uiVisible,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(_videoPlayerController!.value.position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 6.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8.0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 24.0,
                          ),
                          activeTrackColor: Colors.blue,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.blue,
                          overlayColor: Colors.blue.withValues(alpha: 0.3),
                        ),
                        child: Slider(
                          value: _videoPlayerController!.value.position.inMilliseconds.toDouble().clamp(
                            0.0,
                            _videoPlayerController!.value.duration.inMilliseconds.toDouble() > 0
                                ? _videoPlayerController!.value.duration.inMilliseconds.toDouble()
                                : 1.0,
                          ),
                          min: 0.0,
                          max: _videoPlayerController!.value.duration.inMilliseconds.toDouble() > 0
                              ? _videoPlayerController!.value.duration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (value) {
                            _videoPlayerController!.seekTo(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_videoPlayerController!.value.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}