import 'package:flutter/material.dart';
import 'package:nya_image_manage/services/thumbnail_cache.dart';
import 'package:provider/provider.dart';
import 'utils/backend_provider.dart';
import 'screens/init_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThumbnailCache.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => BackendProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '图片管理工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const InitScreen(),
    );
  }
}