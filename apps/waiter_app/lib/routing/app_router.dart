import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import '../viewmodels/waiter_auth_viewmodel.dart';
import '../screens/waiter_auth_screen.dart';
import '../screens/waiter_main_screen.dart';
import '../screens/quick_order_screen.dart';

/// Provider định tuyến GoRouter cho Waiter App.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(waiterAuthViewModelProvider);
  final currentUserAsync = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = authState.value ?? currentUserAsync.value;
      final isLoggingIn = state.matchedLocation == '/login';

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      // Đã đăng nhập
      if (isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WaiterMainScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const WaiterAuthScreen(),
      ),
      GoRoute(
        path: '/quick-order',
        builder: (context, state) {
          final sessionId = state.uri.queryParameters['sessionId'] ?? '';
          final tableId = state.uri.queryParameters['tableId'] ?? '';
          final tableName = state.uri.queryParameters['tableName'] ?? 'Bàn';
          return QuickOrderScreen(
            sessionId: sessionId,
            tableId: tableId,
            tableName: tableName,
          );
        },
      ),
    ],
  );
});
