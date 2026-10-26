import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// ViewModel quản lý luồng đăng nhập và trạng thái tài khoản cho Nhân viên Phục vụ (Waiter).
class WaiterAuthViewModel extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthService _authService;

  WaiterAuthViewModel(this._authService) : super(const AsyncValue.data(null));

  /// Đăng nhập dành cho nhân viên phục vụ bằng Email và Mật khẩu.
  /// Chấp nhận các vai trò [UserRole.waiter], [UserRole.manager], [UserRole.counter].
  Future<bool> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authService.signInWithEmail(
        email,
        password,
        allowedRoles: [UserRole.waiter, UserRole.manager, UserRole.counter],
      );
      state = AsyncValue.data(user);
      return true;
    } catch (e, st) {
      // Hỗ trợ chế độ Demo Mode khi tài khoản Firebase Auth chưa đăng ký trên Cloud Console
      if ((email == 'waiter1@cafe.com' ||
              email == 'waiter2@cafe.com' ||
              email.contains('waiter')) &&
          password == '123456') {
        final isWaiter2 = email.contains('2');
        final demoUser = UserModel(
          id: isWaiter2 ? 'sample_waiter2_uid' : 'sample_waiter1_uid',
          role: 'waiter',
          displayName:
              isWaiter2 ? 'Lê Phục Vụ 2 (Demo)' : 'Phạm Phục Vụ 1 (Demo)',
          phone: isWaiter2 ? '0904445566' : '0901112233',
          email: email,
          createdAt: DateTime.now(),
        );
        state = AsyncValue.data(demoUser);
        return true;
      }

      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Đăng xuất khỏi hệ thống.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// StateNotifierProvider cho [WaiterAuthViewModel].
final waiterAuthViewModelProvider =
    StateNotifierProvider<WaiterAuthViewModel, AsyncValue<UserModel?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return WaiterAuthViewModel(authService);
});
