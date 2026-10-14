import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

/// Thông tin người dùng trong hệ thống (Khách hàng, Phục vụ, Thu ngân, Quản lý).
/// Firestore path: `users/{uid}`.
class UserModel {
  /// Mã định danh người dùng (Firebase Auth UID).
  final String id;

  /// Vai trò tài khoản ('customer', 'waiter', 'counter', 'manager').
  final String role;

  /// Họ tên hiển thị.
  final String displayName;

  /// Số điện thoại (dùng để tìm kiếm thành viên tích điểm tại quầy).
  final String phone;

  /// Địa chỉ email.
  final String email;

  /// Số điểm tích lũy hiện tại của khách hàng.
  final int points;

  /// Danh sách FCM token nhận thông báo đẩy.
  final List<String> fcmTokens;

  /// Thời điểm tạo tài khoản.
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.role,
    required this.displayName,
    required this.phone,
    required this.email,
    this.points = 0,
    this.fcmTokens = const [],
    required this.createdAt,
  });

  /// Chuyển đổi chuỗi role thành Enum [UserRole].
  UserRole get userRole => UserRole.fromString(role);

  /// Kiểm tra xem người dùng có phải là nhân viên quán hay không.
  bool get isStaff =>
      userRole == UserRole.waiter ||
      userRole == UserRole.counter ||
      userRole == UserRole.manager;

  /// Khởi tạo UserModel từ Firestore Document Map.
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      role: map['role'] as String? ?? 'customer',
      displayName: map['displayName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
      fcmTokens: (map['fcmTokens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Chuyển đối tượng thành Map để lưu trữ trên Firestore.
  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'displayName': displayName,
      'phone': phone,
      'email': email,
      'points': points,
      'fcmTokens': fcmTokens,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Tạo bản sao có cập nhật thuộc tính.
  UserModel copyWith({
    String? id,
    String? role,
    String? displayName,
    String? phone,
    String? email,
    int? points,
    List<String>? fcmTokens,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      points: points ?? this.points,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Lịch sử biến động điểm tích lũy của khách hàng.
/// Firestore path: `users/{uid}/pointTx/{txId}`.
class PointTxModel {
  /// Mã giao dịch điểm.
  final String id;

  /// Loại giao dịch: 'earn', 'redeem', 'bonus_early_release', 'bonus_preorder'.
  final String type;

  /// Số điểm biến động (+ hoặc -).
  final int points;

  /// Mã phiên bàn liên quan.
  final String sessionId;

  /// Thời điểm giao dịch phát sinh.
  final DateTime at;

  const PointTxModel({
    required this.id,
    required this.type,
    required this.points,
    required this.sessionId,
    required this.at,
  });

  /// Khởi tạo PointTxModel từ Firestore Map.
  factory PointTxModel.fromMap(Map<String, dynamic> map, String id) {
    return PointTxModel(
      id: id,
      type: map['type'] as String? ?? 'earn',
      points: (map['points'] as num?)?.toInt() ?? 0,
      sessionId: map['sessionId'] as String? ?? '',
      at: _parseDateTime(map['at']),
    );
  }

  /// Chuyển đối tượng thành Map lưu Firestore.
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'points': points,
      'sessionId': sessionId,
      'at': Timestamp.fromDate(at),
    };
  }

  /// Tạo bản sao có chỉnh sửa thuộc tính.
  PointTxModel copyWith({
    String? id,
    String? type,
    int? points,
    String? sessionId,
    DateTime? at,
  }) {
    return PointTxModel(
      id: id ?? this.id,
      type: type ?? this.type,
      points: points ?? this.points,
      sessionId: sessionId ?? this.sessionId,
      at: at ?? this.at,
    );
  }
}

