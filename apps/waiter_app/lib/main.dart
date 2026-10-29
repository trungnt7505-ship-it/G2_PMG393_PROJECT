import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:core/core.dart';
import 'firebase_options.dart';
import 'routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: WaiterStartup(),
    ),
  );
}

/// Hiển thị lỗi khởi tạo và cho phép thử lại thay vì trang trắng khi demo.
class WaiterStartup extends StatefulWidget {
  const WaiterStartup({super.key, this.initialize});
  final Future<void> Function()? initialize;
  @override
  State<WaiterStartup> createState() => _WaiterStartupState();
}

class _WaiterStartupState extends State<WaiterStartup> {
  late Future<Object?> _startup;
  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<Object?> _initialize() async {
    try {
      if (widget.initialize != null) {
        await widget.initialize!();
      } else {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform);
        }
        if (!kIsWeb) await AlarmService.instance.init();
      }
      return null;
    } catch (error) {
      return error;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Object?>(
        future: _startup,
        builder: (context, snapshot) {
          final failed = snapshot.hasError || snapshot.data != null;
          if (snapshot.connectionState == ConnectionState.done && !failed) {
            return const WaiterApp();
          }
          return MaterialApp(
              home: Scaffold(
                  body: Center(
                      child: Padding(
            padding: const EdgeInsets.all(24),
            child: failed
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Không kết nối được Firebase. Kiểm tra mạng rồi thử lại.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: () => setState(() {
                              _startup = _initialize();
                            }),
                        child: const Text('Thử lại')),
                  ])
                : const CircularProgressIndicator(),
          ))));
        },
      );
}

/// Root Widget cho Ứng dụng Nhân viên Phục vụ [WaiterApp].
class WaiterApp extends ConsumerWidget {
  const WaiterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Cafe Waiter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
