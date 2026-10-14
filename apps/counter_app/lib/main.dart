import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:core/core.dart';
import 'routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase nếu chưa được khởi tạo
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Tránh lỗi khởi tạo kép trên một số nền tảng
  }

  // Khởi tạo dịch vụ chuông báo và rung Haptic
  await AlarmService.instance.init();

  runApp(
    const ProviderScope(
      child: CounterApp(),
    ),
  );
}

/// Ứng dụng Quầy POS và Quản lý quán Cafe (Phụ trách: TRƯỜNG).
class CounterApp extends ConsumerWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Cafe POS System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
