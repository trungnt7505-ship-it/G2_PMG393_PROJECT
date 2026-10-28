import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Màn hình đăng nhập và đăng ký tài khoản Khách hàng (MVVM Pattern).
///
/// Sử dụng [AuthViewModel] xử lý nghiệp vụ, không gọi Firebase trực tiếp trong View.
class CustomerAuthScreen extends ConsumerStatefulWidget {
  const CustomerAuthScreen({super.key});

  @override
  ConsumerState<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends ConsumerState<CustomerAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = ref.read(authViewModelProvider.notifier);
    final state = ref.read(authViewModelProvider);

    if (state.isRegistering) {
      await vm.registerCustomer(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        phone: _phone.text,
      );
    } else {
      await vm.signInWithEmail(
        email: _email.text,
        password: _password.text,
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authViewModelProvider.notifier).signInWithGoogle();
  }

  Future<void> _resetPassword() async {
    await ref
        .read(authViewModelProvider.notifier)
        .sendPasswordResetEmail(_email.text);
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final isValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return isValid ? null : 'Vui lòng nhập email hợp lệ.';
  }

  String? _validatePassword(String? value, bool isRegistering) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (isRegistering && value.length < 8) {
      return 'Mật khẩu đăng ký cần có ít nhất 8 ký tự.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final isWide = MediaQuery.sizeOf(context).width > 720;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 980 : 460),
              child: isWide
                  ? _wideLayout(context, authState)
                  : _authCard(context, authState, showBrand: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context, AuthState authState) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 35,
              offset: Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(child: _brandPanel(context)),
            Expanded(child: _authCard(context, authState, showBrand: false)),
          ],
        ),
      );

  Widget _brandPanel(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 690),
        padding: const EdgeInsets.all(44),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3E2723), Color(0xFF795548), Color(0xFF9B6B50)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _CafeMark(size: 74),
            const SizedBox(height: 32),
            Text(
              'Một góc nhỏ,\nmột ngày dịu dàng.',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
            ),
            const SizedBox(height: 18),
            Text(
              'Đặt bàn, gọi món và tích điểm yêu thương\ntrong mỗi lần ghé quán.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: .82),
                    height: 1.6,
                  ),
            ),
          ],
        ),
      );

  Widget _authCard(
    BuildContext context,
    AuthState authState, {
    required bool showBrand,
  }) =>
      Container(
        padding: EdgeInsets.all(showBrand ? 28 : 48),
        decoration: showBrand
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBrand) ...[
              const Center(child: _CafeMark(size: 62)),
              const SizedBox(height: 18),
            ],
            Text(
              authState.isRegistering ? 'Tạo tài khoản' : 'Chào mừng trở lại',
              textAlign: showBrand ? TextAlign.center : TextAlign.left,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF33241F),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              authState.isRegistering
                  ? 'Đăng ký để nhận ưu đãi và tích điểm khi dùng cà phê.'
                  : 'Đăng nhập để đặt bàn, gọi món và tích điểm.',
              textAlign: showBrand ? TextAlign.center : TextAlign.left,
              style: const TextStyle(color: Color(0xFF81756E), height: 1.45),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: authState.isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('Tiếp tục với Google'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF33241F),
                side: const BorderSide(color: Color(0xFFE3DCD5)),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFEAE4DE))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('hoặc dùng email',
                      style: TextStyle(color: Color(0xFF918780), fontSize: 13)),
                ),
                Expanded(child: Divider(color: Color(0xFFEAE4DE))),
              ],
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (authState.isRegistering) ...[
                    _textField(
                      controller: _name,
                      label: 'Họ và tên',
                      icon: Icons.person_outline,
                      validator: (value) =>
                          value == null || value.trim().length < 2
                              ? 'Vui lòng nhập họ tên.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _phone,
                      label: 'Số điện thoại',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value == null || value.trim().length < 9
                              ? 'Vui lòng nhập số điện thoại hợp lệ.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _textField(
                    controller: _email,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _password,
                    label: 'Mật khẩu',
                    icon: Icons.lock_outline,
                    obscureText: authState.hidePassword,
                    validator: (v) => _validatePassword(v, authState.isRegistering),
                    suffix: IconButton(
                      tooltip: authState.hidePassword
                          ? 'Hiện mật khẩu'
                          : 'Ẩn mật khẩu',
                      onPressed: () => ref
                          .read(authViewModelProvider.notifier)
                          .toggleHidePassword(),
                      icon: Icon(authState.hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                ],
              ),
            ),
            if (!authState.isRegistering)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: authState.isLoading ? null : _resetPassword,
                  child: const Text('Quên mật khẩu?'),
                ),
              )
            else
              const SizedBox(height: 16),
            if (authState.errorMessage != null)
              _MessageBox(text: authState.errorMessage!, isError: true),
            if (authState.noticeMessage != null)
              _MessageBox(text: authState.noticeMessage!, isError: false),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: authState.isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5D4037),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: authState.isLoading
                  ? const SizedBox.square(
                      dimension: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(authState.isRegistering ? 'Tạo tài khoản' : 'Đăng nhập'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () => ref
                      .read(authViewModelProvider.notifier)
                      .toggleMode(),
              child: Text(
                authState.isRegistering
                    ? 'Đã có tài khoản? Đăng nhập'
                    : 'Chưa có tài khoản? Đăng ký',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF8A7568)),
          suffixIcon: suffix,
        ),
      );
}

class _CafeMark extends StatelessWidget {
  const _CafeMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE3C9AE), width: 1.5),
        ),
        child: const Icon(Icons.local_cafe_rounded,
            color: Color(0xFF5D4037), size: 34),
      );
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB3261E) : const Color(0xFF28714A);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
