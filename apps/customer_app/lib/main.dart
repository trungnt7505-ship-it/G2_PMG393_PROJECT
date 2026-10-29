import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:core/core.dart';

import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'screens/auth/customer_auth_screen.dart';
import 'screens/home/customer_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase với cấu hình dành riêng cho Customer App
  try {
    await Firebase.initializeApp(
      options: CustomerFirebaseOptions.currentPlatform,
    );

    // Trên Web, tắt IndexedDB offline persistence để tránh deadlock đa tab
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    }
  } catch (e) {
    debugPrint('Firebase customer initialization notice: $e');
  }

  // Khởi tạo dịch vụ chuông báo và rung Haptic cảnh báo sắp hết giờ
  if (!kIsWeb) await AlarmService.instance.init();

  runApp(const ProviderScope(child: CustomerApp()));
}

/// Ứng dụng Khách hàng (CustomerApp - PRM393 Phụ trách: DƯƠNG BÙI).
///
/// Tuân thủ kiến trúc MVVM + Repository/Service Pattern:
/// - Toàn bộ dữ liệu nghiệp vụ đi qua [CustomerRepository] và `packages/core`.
/// - Không truy vấn Firestore trực tiếp trong Widget/View.
/// - Giao diện tối ưu trải nghiệm Mobile dọc với tông màu Cafe ấm áp.
class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'Cafe Customer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8F5F1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F4F0),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFECE5DE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF795548), width: 1.5),
          ),
        ),
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: userAsync.when(
        data: (account) {
          if (account == null || account.userRole != UserRole.customer) {
            return const CustomerAuthScreen();
          }
          return const CustomerHomeScreen();
        },
        loading: () => const _LoadingScreen(),
        error: (error, _) {
          final isLoggedOut = ref.read(authServiceProvider).currentUid == null;
          if (isLoggedOut) {
            return const CustomerAuthScreen();
          }
          return _StartupErrorScreen(message: error.toString());
        },
      ),
    );
  }
}

/// Màn hình chờ trong quá trình khôi phục phiên đăng nhập.
class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen> {
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showFallback = true);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF5D4037)),
              if (_showFallback) ...[
                const SizedBox(height: 20),
                const Text(
                  'Đang kết nối hệ thống...',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Về màn hình Đăng nhập'),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const CustomerAuthScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
}

/// Màn hình thông báo lỗi kết nối khởi động.
class _StartupErrorScreen extends StatelessWidget {
  final String message;

  const _StartupErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 54, color: Colors.brown),
                const SizedBox(height: 16),
                const Text(
                  'Không thể kết nối Firebase hoặc tải dữ liệu hồ sơ.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
