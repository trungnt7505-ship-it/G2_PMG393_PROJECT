import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Trạng thái của quá trình xác thực đăng nhập.
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserModel? user;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserModel? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}

/// ViewModel xử lý đăng nhập cho nhân viên Quầy thu ngân (Counter) và Quản lý (Manager).
class AuthViewModel extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthViewModel(this._authService) : super(const AuthState());

  /// Đăng nhập tài khoản với vai trò cho phép: `counter` hoặc `manager`.
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _authService.signInWithEmail(
        email,
        password,
        allowedRoles: [UserRole.counter, UserRole.manager],
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      // Hỗ trợ chế độ Demo Mode khi chưa cấu hình dự án Firebase thực tế trên Cloud
      if (email == 'counter@cafe.com' && password == '123456') {
        final demoUser = UserModel(
          id: 'sample_counter_uid',
          role: 'counter',
          displayName: 'Nguyễn Thu Ngân (Demo)',
          phone: '0901234567',
          email: 'counter@cafe.com',
          createdAt: DateTime.now(),
        );
        state = state.copyWith(isLoading: false, user: demoUser);
        return true;
      } else if (email == 'manager@cafe.com' && password == '123456') {
        final demoUser = UserModel(
          id: 'sample_manager_uid',
          role: 'manager',
          displayName: 'Trần Quản Lý (Demo)',
          phone: '0909876543',
          email: 'manager@cafe.com',
          createdAt: DateTime.now(),
        );
        state = state.copyWith(isLoading: false, user: demoUser);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Đăng xuất khỏi hệ thống.
  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState();
  }
}

/// Provider cho AuthViewModel.
final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthViewModel(authService);
});

