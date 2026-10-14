import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import '../screens/counter_auth_screen.dart';
import '../screens/pos_dashboard_screen.dart';
import '../screens/manager_admin_screen.dart';

/// Quản lý định tuyến (Routing) cho Counter App bằng GoRouter kết hợp Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  final currentUserState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/pos',
    redirect: (context, state) {
      final isLoading = currentUserState.isLoading;
      final user = currentUserState.value;
      final isLoggingIn = state.matchedLocation == '/login';

      if (isLoading) return null;

      // Nếu chưa đăng nhập hoặc không phải nhân viên quầy/quản lý -> chuyển về trang Login
      if (user == null || (user.userRole != UserRole.counter && user.userRole != UserRole.manager)) {
        return isLoggingIn ? null : '/login';
      }

      // Nếu đã đăng nhập mà đang ở trang login -> đưa vào POS dashboard
      if (isLoggingIn) {
        return '/pos';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const CounterAuthScreen(),
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) => const PosDashboardScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const ManagerAdminScreen(),
      ),
    ],
  );
});
