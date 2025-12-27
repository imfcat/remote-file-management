import 'dart:async';
import 'package:flutter/material.dart';

enum NotificationType {
  success(Colors.green, Icons.check_circle),
  error(Colors.red, Icons.error),
  warning(Colors.orange, Icons.warning),
  info(Colors.blue, Icons.info);

  final Color color;
  final IconData icon;
  const NotificationType(this.color, this.icon);
}

class AppNotification {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static OverlayEntry? _currentEntry;
  static Timer? _hideTimer;

  static void show({
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 1),
  }) {
    // 移除当前的弹窗
    _hideTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    // 获取 OverlayState
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    // 创建新的 Entry
    _currentEntry = OverlayEntry(
      builder: (context) => _NotificationWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    overlayState.insert(_currentEntry!);

    // 定时自动移除
    _hideTimer = Timer(duration + const Duration(milliseconds: 500), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    // 整个弹窗的弹出动画
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // 在倒计时结束前开始退场动画
    Future.delayed(widget.duration, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias, // 剪裁底部的进度条
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(widget.type.icon, color: widget.type.color, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 底部倒计时进度条
                  _CountdownBar(
                    duration: widget.duration,
                    color: widget.type.color,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownBar extends StatefulWidget {
  final Duration duration;
  final Color color;

  const _CountdownBar({required this.duration, required this.color});

  @override
  State<_CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<_CountdownBar> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    // 进度条从 1 变到 0
    _progressController.reverse(from: 1.0);
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Container(
          height: 4,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _progressController.value,
            child: Container(color: widget.color),
          ),
        );
      },
    );
  }
}