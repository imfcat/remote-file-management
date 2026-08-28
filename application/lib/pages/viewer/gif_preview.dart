import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../utils/custom_cache.dart';

class GifPreview extends StatefulWidget {
  final String imageUrl;
  final String cacheKey;
  final bool uiVisible;
  final bool showIndicator;

  const GifPreview({
    super.key,
    required this.imageUrl,
    required this.cacheKey,
    required this.uiVisible,
    required this.showIndicator,
  });

  @override
  State<GifPreview> createState() => _GifPreviewState();
}

class _GifFrame {
  final ui.Image image;
  final Duration duration;

  const _GifFrame(this.image, this.duration);
}

class _GifPreviewState extends State<GifPreview>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  List<_GifFrame> _frames = const [];
  int _frameIndex = 0;
  bool _loading = true;
  bool _failed = false;
  bool _playing = false;

  bool get _hasAnimation => _frames.length > 1;

  Duration get _totalDuration {
    var ms = 0;
    for (final frame in _frames) {
      ms += frame.duration.inMilliseconds;
    }
    return Duration(milliseconds: ms <= 0 ? 1 : ms);
  }

  Duration get _elapsed {
    final controller = _controller;
    if (controller == null) return Duration.zero;
    return Duration(
      milliseconds: (controller.value * _totalDuration.inMilliseconds).round(),
    );
  }

  @override
  void initState() {
    super.initState();
    _load(widget.imageUrl, widget.cacheKey, notify: false);
  }

  @override
  void didUpdateWidget(GifPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey) {
      _load(widget.imageUrl, widget.cacheKey, notify: true);
    }
  }

  @override
  void dispose() {
    _disposePlayback();
    super.dispose();
  }

  void _disposePlayback() {
    _controller?.dispose();
    _controller = null;
    for (final frame in _frames) {
      frame.image.dispose();
    }
    _frames = const [];
  }

  Duration _normalizeDuration(Duration duration) {
    if (duration.inMilliseconds < 20) {
      return const Duration(milliseconds: 100);
    }
    return duration;
  }

  bool _isCurrentRequest(String url, String cacheKey) {
    return url == widget.imageUrl && cacheKey == widget.cacheKey;
  }

  Future<void> _load(String url, String cacheKey, {required bool notify}) async {
    _disposePlayback();
    _loading = true;
    _failed = false;
    _frameIndex = 0;
    _playing = false;
    if (notify && mounted) setState(() {});

    try {
      final file = await customCacheManager().getSingleFile(url, key: cacheKey);
      if (!mounted || !_isCurrentRequest(url, cacheKey)) return;

      final bytes = await file.readAsBytes();
      if (!mounted || !_isCurrentRequest(url, cacheKey)) return;

      final codec = await ui.instantiateImageCodec(bytes);
      final frames = <_GifFrame>[];
      for (var i = 0; i < codec.frameCount; i++) {
        final info = await codec.getNextFrame();
        frames.add(_GifFrame(info.image, _normalizeDuration(info.duration)));
      }

      if (!mounted || !_isCurrentRequest(url, cacheKey)) {
        for (final frame in frames) {
          frame.image.dispose();
        }
        return;
      }

      _frames = frames;
      _loading = false;
      _failed = frames.isEmpty;
      if (frames.length > 1) {
        _controller = AnimationController(vsync: this, duration: _totalDuration)
          ..addListener(_onTick)
          ..repeat();
        _playing = true;
      }
      setState(() {});
    } catch (e) {
      debugPrint('GIF 加载失败：$e');
      if (!mounted || !_isCurrentRequest(url, cacheKey)) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onTick() {
    if (!mounted || _frames.isEmpty) return;
    final next = _frameIndexFor(_elapsed);
    if (next != _frameIndex || widget.showIndicator) {
      setState(() => _frameIndex = next);
    } else {
      _frameIndex = next;
    }
  }

  int _frameIndexFor(Duration elapsed) {
    final totalMs = _totalDuration.inMilliseconds;
    var ms = elapsed.inMilliseconds;
    if (totalMs <= 0) return 0;
    if (ms >= totalMs) ms = totalMs - 1;
    var acc = 0;
    for (var i = 0; i < _frames.length; i++) {
      acc += _frames[i].duration.inMilliseconds;
      if (ms < acc) return i;
    }
    return _frames.length - 1;
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !_hasAnimation) return;
    if (_playing) {
      controller.stop();
      _playing = false;
    } else {
      if (controller.value >= 1.0) {
        controller.value = 0;
      }
      controller.repeat();
      _playing = true;
    }
    setState(() {});
  }

  void _seek(double milliseconds) {
    final controller = _controller;
    if (controller == null || !_hasAnimation) return;
    final maxMs = _totalDuration.inMilliseconds.toDouble();
    final value = maxMs <= 0 ? 0.0 : (milliseconds / maxMs).clamp(0.0, 1.0);
    final wasPlaying = _playing;
    controller.stop();
    controller.value = value;
    _frameIndex = _frameIndexFor(_elapsed);
    if (wasPlaying) {
      controller.repeat();
    }
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_failed || _frames.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gif_box_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text('无法加载 GIF', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    final showBar =
        widget.showIndicator && widget.uiVisible && _hasAnimation;
    final maxMs = _totalDuration.inMilliseconds.toDouble();
    final currentMs = _elapsed.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: RawImage(
              image: _frames[_frameIndex].image,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: showBar ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !showBar,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 24, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlay,
                    ),
                    Text(
                      _formatDuration(_elapsed),
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
                          value: currentMs,
                          min: 0.0,
                          max: maxMs > 0 ? maxMs : 1.0,
                          onChanged: _seek,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_totalDuration),
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
