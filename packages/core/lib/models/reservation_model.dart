import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';
import 'order_model.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

/// Đơn đặt bàn trước của khách hàng.
/// Firestore path: `reservations/{resId}`.
class ReservationModel {
  /// Mã đơn đặt trước.
  final String id;

  /// UID khách hàng đặt bàn.
  final String customerId;

  /// Tên khách hàng.
  final String customerName;

  /// Số điện thoại liên hệ.
  final String phone;

  /// Mã bàn đã chọn đặt trước.
  final String tableId;

  /// Tên bàn hiển thị.
  final String tableName;

  /// Số lượng khách đi cùng.
  final int partySize;

  /// Thời điểm hẹn bắt đầu dùng bàn.
  final DateTime startTime;

  /// Thời điểm kết thúc dự kiến (thường là startTime + 120 phút).
  final DateTime endTime;

  /// Hạn chót giữ chỗ (mặc định startTime + 15 phút, quá giờ đánh dấu no_show).
  final DateTime holdUntil;

  /// Trạng thái: 'confirmed', 'checked_in', 'no_show', 'cancelled', 'completed'.
  final String status;

  /// Danh sách các món đặt trước (nếu có).
  final List<OrderItemModel> preOrderItems;

  /// Mã phiên bàn sau khi đã check-in thành công.
  final String? sessionId;

  /// Thời điểm tạo đơn đặt chỗ.
  final DateTime createdAt;

  const ReservationModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.tableId,
    required this.tableName,
    required this.partySize,
    required this.startTime,
    required this.endTime,
    required this.holdUntil,
    this.status = 'confirmed',
    this.preOrderItems = const [],
    this.sessionId,
    required this.createdAt,
  });

  /// Chuỗi URI mã QR đơn đặt trước: `cafe://preorder/{resId}`.
  String get qrUrl => 'cafe://preorder/$id';

  /// Chuyển đổi trạng thái sang [ReservationStatus].
  ReservationStatus get reservationStatus =>
      ReservationStatus.fromString(status);

  /// Kiểm tra xem đơn đặt bàn có kèm món đặt trước hay không.
  bool get hasPreOrder => preOrderItems.isNotEmpty;

  /// Tổng tiền các món đặt trước.
  int get preOrderTotal =>
      preOrderItems.fold(0, (sum, item) => sum + item.totalPrice);

  factory ReservationModel.fromMap(Map<String, dynamic> map, String id) {
    return ReservationModel(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      tableId: map['tableId'] as String? ?? '',
      tableName: map['tableName'] as String? ?? '',
      partySize: (map['partySize'] as num?)?.toInt() ?? 2,
      startTime: _parseDateTime(map['startTime']),
      endTime: _parseDateTime(map['endTime']),
      holdUntil: _parseDateTime(map['holdUntil']),
      status: map['status'] as String? ?? 'confirmed',
      preOrderItems: (map['preOrderItems'] as List<dynamic>?)
              ?.map((e) =>
                  OrderItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      sessionId: map['sessionId'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'phone': phone,
      'tableId': tableId,
      'tableName': tableName,
      'partySize': partySize,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'holdUntil': Timestamp.fromDate(holdUntil),
      'status': status,
      'preOrderItems': preOrderItems.map((e) => e.toMap()).toList(),
      'sessionId': sessionId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ReservationModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? phone,
    String? tableId,
    String? tableName,
    int? partySize,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? holdUntil,
    String? status,
    List<OrderItemModel>? preOrderItems,
    String? sessionId,
    DateTime? createdAt,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      partySize: partySize ?? this.partySize,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      holdUntil: holdUntil ?? this.holdUntil,
      status: status ?? this.status,
      preOrderItems: preOrderItems ?? this.preOrderItems,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

