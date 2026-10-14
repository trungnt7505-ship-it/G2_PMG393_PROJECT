import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Màn hình đăng nhập dành riêng cho Thu ngân (Counter) và Quản lý (Manager).
class CounterAuthScreen extends ConsumerStatefulWidget {
  const CounterAuthScreen({super.key});

  @override
  ConsumerState<CounterAuthScreen> createState() => _CounterAuthScreenState();
}

class _CounterAuthScreenState extends ConsumerState<CounterAuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ Email và Mật khẩu.')),
      );
      return;
    }

    final success = await ref
        .read(authViewModelProvider.notifier)
        .signIn(email, password);

    if (success && mounted) {
      context.go('/pos');
    }
  }

  void _fillSampleAccount(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.brown.shade50,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.shade200.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Tiêu đề
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.point_of_sale, size: 56, color: AppColors.primary),
                      SizedBox(height: 12),
                      Text(
                        'POS & MANAGEMENT',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Đăng nhập dành cho Thu ngân & Quản lý',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Form Email
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email nhân viên',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Form Password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  onSubmitted: (_) => _submitLogin(),
                ),

                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Nút Đăng nhập
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _submitLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Đăng nhập vào POS',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 24),
                const Divider(),

                // Tài khoản mẫu hỗ trợ chấm bài
                const Text(
                  'Tài khoản mẫu dùng thử:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _fillSampleAccount('counter@cafe.com', '123456'),
                        child: const Text('Thu ngân (Counter)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _fillSampleAccount('manager@cafe.com', '123456'),
                        child: const Text('Quản lý (Manager)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
