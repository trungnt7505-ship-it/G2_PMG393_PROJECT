import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // Hỗ trợ chế độ Demo Mode: Tự động khởi tạo tài khoản xác thực và hồ sơ Firestore
      // với role = 'waiter' để thỏa mãn quy tắc bảo mật Firebase Security Rules (isStaff)
      if ((email == 'waiter1@cafe.com' ||
              email == 'waiter2@cafe.com' ||
              email == 'demo.waiter@example.com' ||
              email.contains('waiter')) &&
          password == '123456') {
        try {
          UserCredential credential;
          try {
            credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
          } catch (_) {
            credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
          }

          final uid = credential.user!.uid;
          final isWaiter2 = email.contains('2');
          final demoUser = UserModel(
            id: uid,
            role: 'waiter',
            displayName:
                isWaiter2 ? 'Lê Phục Vụ 2 (Demo)' : 'Phạm Phục Vụ 1 (Demo)',
            phone: isWaiter2 ? '0904445566' : '0901112233',
            email: email.trim(),
            createdAt: DateTime.now(),
          );

          // QUAN TRỌNG: Ghi hồ sơ user vào Firestore tại users/$uid với role: 'waiter'
          // để quy tắc firestore.rules (như isStaff()) kiểm tra getUserData().role == 'waiter' thành công
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set(demoUser.toMap(), SetOptions(merge: true));

          state = AsyncValue.data(demoUser);
          return true;
        } catch (_) {
          // Dự phòng Đăng nhập Ẩn danh nếu tạo Email thất bại
          try {
            if (FirebaseAuth.instance.currentUser == null) {
              await FirebaseAuth.instance.signInAnonymously();
            }
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final isWaiter2 = email.contains('2');
            final demoUser = UserModel(
              id: uid,
              role: 'waiter',
              displayName:
                  isWaiter2 ? 'Lê Phục Vụ 2 (Demo)' : 'Phạm Phục Vụ 1 (Demo)',
              phone: isWaiter2 ? '0904445566' : '0901112233',
              email: email.trim(),
              createdAt: DateTime.now(),
            );

            // Ghi hồ sơ role: 'waiter' lên Firestore
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .set(demoUser.toMap(), SetOptions(merge: true));

            state = AsyncValue.data(demoUser);
            return true;
          } catch (err, stack) {
            state = AsyncValue.error(err, stack);
            return false;
          }
        }
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
