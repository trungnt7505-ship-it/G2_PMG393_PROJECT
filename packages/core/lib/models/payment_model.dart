import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

/// Hóa đơn thanh toán của một phiên bàn hoặc đơn mang đi.
/// Firestore path: `payments/{payId}`.
class PaymentModel {
  /// Mã hóa đơn thanh toán.
  final String id;

  /// Mã phiên bàn liên quan.
  final String sessionId;

  /// Mã bàn.
  final String tableId;

  /// Tên bàn hiển thị.
  final String tableName;

  /// UID thu ngân/nhân viên xác nhận thu tiền.
  final String cashierId;

  /// Phương thức thanh toán: 'cash', 'qr', 'card'.
  final String method;

  /// Tổng tiền trước giảm giá (VND).
  final int subtotal;

  /// Số điểm thành viên đã sử dụng để giảm trừ.
  final int pointsUsed;

  /// Số tiền được giảm giá quy đổi từ điểm thành viên (VND).
  final int discount;

  /// Số tiền thực thu cuối cùng của khách sau khi giảm giá (VND).
  final int total;

  /// Số điểm tích lũy nhận được từ đơn hàng (10.000đ = 1 điểm).
  final int pointsEarned;

  /// Điểm thưởng thêm (trả bàn sớm +20 điểm, đặt món trước +10 điểm).
  final int bonusPoints;

  /// UID khách hàng nếu có tích điểm (null nếu khách vãng lai).
  final String? customerId;

  /// Thời điểm hoàn tất thanh toán.
  final DateTime paidAt;

  const PaymentModel({
    required this.id,
    required this.sessionId,
    required this.tableId,
    required this.tableName,
    required this.cashierId,
    required this.method,
    required this.subtotal,
    this.pointsUsed = 0,
    this.discount = 0,
    required this.total,
    this.pointsEarned = 0,
    this.bonusPoints = 0,
    this.customerId,
    required this.paidAt,
  });

  /// Chuyển đổi phương thức thanh toán sang [PaymentMethod].
  PaymentMethod get paymentMethod => PaymentMethod.fromString(method);

  /// Tổng số điểm khách nhận được từ hóa đơn này (tích lũy + thưởng).
  int get totalPointsReceived => pointsEarned + bonusPoints;

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id: id,
      sessionId: map['sessionId'] as String? ?? '',
      tableId: map['tableId'] as String? ?? '',
      tableName: map['tableName'] as String? ?? '',
      cashierId: map['cashierId'] as String? ?? '',
      method: map['method'] as String? ?? 'cash',
      subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
      pointsUsed: (map['pointsUsed'] as num?)?.toInt() ?? 0,
      discount: (map['discount'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      pointsEarned: (map['pointsEarned'] as num?)?.toInt() ?? 0,
      bonusPoints: (map['bonusPoints'] as num?)?.toInt() ?? 0,
      customerId: map['customerId'] as String?,
      paidAt: _parseDateTime(map['paidAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'tableId': tableId,
      'tableName': tableName,
      'cashierId': cashierId,
      'method': method,
      'subtotal': subtotal,
      'pointsUsed': pointsUsed,
      'discount': discount,
      'total': total,
      'pointsEarned': pointsEarned,
      'bonusPoints': bonusPoints,
      'customerId': customerId,
      'paidAt': Timestamp.fromDate(paidAt),
    };
  }

  PaymentModel copyWith({
    String? id,
    String? sessionId,
    String? tableId,
    String? tableName,
    String? cashierId,
    String? method,
    int? subtotal,
    int? pointsUsed,
    int? discount,
    int? total,
    int? pointsEarned,
    int? bonusPoints,
    String? customerId,
    DateTime? paidAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      cashierId: cashierId ?? this.cashierId,
      method: method ?? this.method,
      subtotal: subtotal ?? this.subtotal,
      pointsUsed: pointsUsed ?? this.pointsUsed,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      bonusPoints: bonusPoints ?? this.bonusPoints,
      customerId: customerId ?? this.customerId,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}

