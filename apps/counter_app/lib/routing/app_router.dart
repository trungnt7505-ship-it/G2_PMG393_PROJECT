import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../screens/counter_auth_screen.dart';
import '../screens/pos_dashboard_screen.dart';
import '../screens/manager_admin_screen.dart';

/// Quản lý định tuyến (Routing) cho Counter App bằng GoRouter kết hợp Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authViewModelProvider);
  final currentUserState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = authState.user ?? currentUserState.value;
      final isLoggingIn = state.matchedLocation == '/login';

      // Nếu chưa đăng nhập hoặc không phải nhân viên quầy/quản lý -> chuyển về trang Login
      if (user == null || (user.userRole != UserRole.counter && user.userRole != UserRole.manager)) {
        return isLoggingIn ? null : '/login';
      }

      // Nếu đã đăng nhập mà đang ở trang login -> đưa vào POS dashboard
      if (isLoggingIn) {
        return '/pos';
      }

      // Bảo vệ cả đường dẫn nhập trực tiếp, không chỉ ẩn nút trên giao diện.
      if (state.matchedLocation == '/admin' &&
          user.userRole != UserRole.manager) {
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
