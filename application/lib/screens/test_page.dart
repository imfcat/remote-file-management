import 'package:flutter/material.dart';

import '../widget/notification.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('测试页面'),
        backgroundColor: Colors.black87,
        toolbarHeight: 60,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => AppNotification.show(message: "info message", type: NotificationType.info),
              child: const Text("info"),
            ),
            ElevatedButton(
              onPressed: () => AppNotification.show(message: "success message", type: NotificationType.success),
              child: const Text("success"),
            ),
            ElevatedButton(
              onPressed: () => AppNotification.show(message: "warning message", type: NotificationType.warning),
              child: const Text("warning"),
            ),
            ElevatedButton(
              onPressed: () => AppNotification.show(message: "error message", type: NotificationType.error, duration: Duration(seconds: 4)),
              child: const Text("error"),
            ),
          ],
        ),
      ),
    );
  }
}