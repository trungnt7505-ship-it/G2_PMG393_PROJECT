import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/enums.dart';
import '../models/user_model.dart';
import 'clock_service.dart';

/// Dịch vụ xác thực và quản lý tài khoản người dùng với Firebase Auth & Firestore.
class AuthService {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _customAuth = auth,
        _customFirestore = firestore;

  /// Lấy UID người dùng hiện tại (nếu đã đăng nhập).
  String? get currentUid => _auth.currentUser?.uid;

  /// Lắng nghe thông tin người dùng hiện tại theo thời gian thực (Realtime Stream).
  Stream<UserModel?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) {
        return Stream.value(null);
      }
      return _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return UserModel.fromMap(snapshot.data()!, snapshot.id);
      });
    });
  }

  /// Đăng nhập bằng Email và Mật khẩu, đồng thời kiểm tra phân quyền [allowedRoles].
  /// Nếu vai trò của tài khoản không nằm trong danh sách cho phép, tự động đăng xuất
  /// và ném ngoại lệ để ngăn chặn đăng nhập chéo giữa các App.
  Future<UserModel> signInWithEmail(
    String email,
    String password, {
    required List<UserRole> allowedRoles,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw Exception('Đăng nhập thất bại: Không tìm thấy thông tin tài khoản.');
    }

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      await _auth.signOut();
      throw Exception('Dữ liệu người dùng chưa được khởi tạo trên hệ thống.');
    }

    final user = UserModel.fromMap(doc.data()!, doc.id);

    // Kiểm tra phân quyền truy cập
    if (!allowedRoles.contains(user.userRole)) {
      await _auth.signOut();
      throw Exception(
        'Tài khoản vai trò "${user.role}" không có quyền truy cập ứng dụng này.',
      );
    }

    // Tự động đồng bộ giờ Server sau khi đăng nhập thành công
    await ClockService.instance.syncClock(uid);

    return user;
  }

  /// Đăng ký tài khoản Khách hàng mới với vai trò mặc định là `customer`.
  Future<UserModel> registerCustomer({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw Exception('Đăng ký thất bại: Không lấy được thông tin xác thực.');
    }

    await credential.user?.updateDisplayName(displayName.trim());

    final newUser = UserModel(
      id: uid,
      role: UserRole.customer.name,
      displayName: displayName.trim(),
      phone: phone.trim(),
      email: email.trim(),
      points: 0,
      fcmTokens: const [],
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set(newUser.toMap());

    // Đồng bộ giờ sau khi tạo tài khoản
    await ClockService.instance.syncClock(uid);

    return newUser;
  }

  /// Đăng xuất tài khoản khỏi thiết bị.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Tìm kiếm thông tin khách hàng dựa theo số điện thoại (dành cho Quầy thu ngân).
  Future<UserModel?> findCustomerByPhone(String phone) async {
    final query = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return UserModel.fromMap(doc.data(), doc.id);
  }
}
