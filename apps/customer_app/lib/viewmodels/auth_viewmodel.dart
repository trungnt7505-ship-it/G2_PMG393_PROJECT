import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Trạng thái của màn hình xác thực Auth.
class AuthState {
  final bool isLoading;
  final bool isRegistering;
  final bool hidePassword;
  final String? errorMessage;
  final String? noticeMessage;

  const AuthState({
    this.isLoading = false,
    this.isRegistering = false,
    this.hidePassword = true,
    this.errorMessage,
    this.noticeMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isRegistering,
    bool? hidePassword,
    String? errorMessage,
    String? noticeMessage,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isRegistering: isRegistering ?? this.isRegistering,
      hidePassword: hidePassword ?? this.hidePassword,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
    );
  }
}

/// ViewModel quản lý toàn bộ luồng đăng nhập, đăng ký và khôi phục mật khẩu.
class AuthViewModel extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthViewModel({required AuthService authService})
      : _authService = authService,
        super(const AuthState());

  void toggleMode() {
    state = state.copyWith(
      isRegistering: !state.isRegistering,
      clearError: true,
      clearNotice: true,
    );
  }

  void toggleHidePassword() {
    state = state.copyWith(hidePassword: !state.hidePassword);
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearNotice: true);
  }

  /// Đăng nhập bằng Email và Mật khẩu.
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearNotice: true);
    try {
      await _authService.signInWithEmail(
        email.trim(),
        password,
        allowedRoles: const [UserRole.customer],
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyErrorMessage(e),
      );
      return false;
    }
  }

  /// Đăng ký tài khoản khách hàng mới.
  Future<bool> registerCustomer({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearNotice: true);
    try {
      await _authService.registerCustomer(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
        phone: phone.trim(),
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyErrorMessage(e),
      );
      return false;
    }
  }

  /// Đăng nhập bằng tài khoản Google.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true, clearNotice: true);
    try {
      await _authService.signInWithGoogle(
        allowedRoles: const [UserRole.customer],
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyErrorMessage(e),
      );
      return false;
    }
  }

  /// Gửi email đặt lại mật khẩu.
  Future<bool> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (!_validEmail(trimmed)) {
      state = state.copyWith(
        errorMessage: 'Vui lòng nhập địa chỉ email hợp lệ vào ô Email.',
        clearNotice: true,
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearNotice: true);
    try {
      await _authService.sendPasswordResetEmail(trimmed);
      state = state.copyWith(
        isLoading: false,
        noticeMessage: 'Đã gửi email đặt lại mật khẩu đến $trimmed.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyErrorMessage(e),
      );
      return false;
    }
  }

  /// Đăng xuất khỏi hệ thống.
  Future<void> signOut() async {
    await _authService.signOut();
  }

  bool _validEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  /// Chuyển đổi mã lỗi Firebase sang thông điệp tiếng Việt thân thiện với người dùng.
  String _friendlyErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('popup-closed-by-user') ||
        message.contains('cancelled-popup-request')) {
      return 'Bạn đã đóng cửa sổ đăng nhập Google.';
    }
    if (message.contains('account-exists-with-different-credential')) {
      return 'Email này đã được đăng ký bằng phương thức khác.';
    }
    if (message.contains('email-already-in-use')) {
      return 'Email này đã có tài khoản. Vui lòng đăng nhập thay vì tạo mới.';
    }
    if (message.contains('invalid-credential') ||
        message.contains('wrong-password') ||
        message.contains('user-not-found')) {
      return 'Email hoặc mật khẩu không chính xác.';
    }
    if (message.contains('network-request-failed')) {
      return 'Không có kết nối mạng. Vui lòng kiểm tra lại Wifi/4G.';
    }
    if (message.contains('role') || message.contains('Role')) {
      return 'Tài khoản này là tài khoản nhân viên, không dùng cho ứng dụng khách hàng.';
    }
    return message.replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
  }
}

/// Provider quản lý AuthViewModel.
final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  return AuthViewModel(authService: ref.watch(authServiceProvider));
});
