import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'utils/settings_provider.dart';
import 'utils/backend_provider.dart';
import 'utils/custom_cache.dart';
import 'screens/init.dart';
import 'widget/notification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initCacheDir();

  // 最大缓存容量
  PaintingBinding.instance.imageCache.maximumSizeBytes = 1024 * 1024 * 500;

  // 最大缓存图片数
  PaintingBinding.instance.imageCache.maximumSize = 1000;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => BackendProvider()),
        ChangeNotifierProvider(create: (ctx) => SettingsProvider()..init()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNotification.navigatorKey,
      title: '图片管理工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const InitScreen(),
    );
  }
}