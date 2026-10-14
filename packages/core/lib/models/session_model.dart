import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

/// Nhật ký các lần gia hạn thời gian của một phiên bàn.
class SessionExtension {
  /// Thời điểm thực hiện gia hạn.
  final DateTime at;

  /// Số phút cộng thêm trong lần gia hạn này (VD: 30).
  final int minutes;

  /// UID người thực hiện gia hạn.
  final String by;

  const SessionExtension({
    required this.at,
    required this.minutes,
    required this.by,
  });

  factory SessionExtension.fromMap(Map<String, dynamic> map) {
    return SessionExtension(
      at: _parseDateTime(map['at']),
      minutes: (map['minutes'] as num?)?.toInt() ?? 30,
      by: map['by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'at': Timestamp.fromDate(at),
      'minutes': minutes,
      'by': by,
    };
  }

  SessionExtension copyWith({
    DateTime? at,
    int? minutes,
    String? by,
  }) {
    return SessionExtension(
      at: at ?? this.at,
      minutes: minutes ?? this.minutes,
      by: by ?? this.by,
    );
  }
}

/// Phiên sử dụng bàn trong quán Cafe.
/// Firestore path: `sessions/{sessionId}`.
class SessionModel {
  /// Mã phiên sử dụng.
  final String id;

  /// Mã bàn đang ngồi.
  final String tableId;

  /// Tên bàn hiển thị.
  final String tableName;

  /// UID khách hàng nếu đã đăng ký / đăng nhập (null nếu khách vãng lai).
  final String? customerId;

  /// Tên khách hàng (Mặc định: 'Khách vãng lai').
  final String customerName;

  /// Số điện thoại khách (nếu có lưu).
  final String? guestPhone;

  /// UID người mở phiên (Nhân viên, Thu ngân, hoặc Khách hàng tự quét QR).
  final String openedBy;

  /// Vai trò người mở phiên ('customer', 'waiter', 'counter').
  final String openedByRole;

  /// Mã đơn đặt trước liên kết (nếu mở phiên từ đặt trước).
  final String? reservationId;

  /// Thời điểm bắt đầu phiên.
  final DateTime startedAt;

  /// Thời lượng phiên tiêu chuẩn ban đầu (phút, mặc định 120).
  final int baseMinutes;

  /// Tổng số phút đã được gia hạn thêm.
  final int extendedMinutes;

  /// Thời điểm hết hạn phiên bàn.
  final DateTime expiresAt;

  /// Danh sách các lượt gia hạn.
  final List<SessionExtension> extensions;

  /// Đã gửi yêu cầu trả bàn sớm hợp lệ để nhận điểm thưởng hay chưa.
  final bool earlyReleased;

  /// Trạng thái phiên: 'active', 'billing', 'paid', 'cancelled'.
  final String status;

  /// Tổng tiền các món đã được xác nhận trong phiên (VND).
  final int subtotal;

  const SessionModel({
    required this.id,
    required this.tableId,
    required this.tableName,
    this.customerId,
    this.customerName = 'Khách vãng lai',
    this.guestPhone,
    required this.openedBy,
    required this.openedByRole,
    this.reservationId,
    required this.startedAt,
    this.baseMinutes = 120,
    this.extendedMinutes = 0,
    required this.expiresAt,
    this.extensions = const [],
    this.earlyReleased = false,
    this.status = 'active',
    this.subtotal = 0,
  });

  /// Chuyển đổi trạng thái sang [SessionStatus].
  SessionStatus get sessionStatus => SessionStatus.fromString(status);

  /// Tổng số phút toàn bộ phiên (gốc + các lần gia hạn).
  int get totalMinutes => baseMinutes + extendedMinutes;

  /// Kiểm tra xem phiên có còn đang hoạt động không.
  bool get isActive => status == 'active' || status == 'billing';

  factory SessionModel.fromMap(Map<String, dynamic> map, String id) {
    return SessionModel(
      id: id,
      tableId: map['tableId'] as String? ?? '',
      tableName: map['tableName'] as String? ?? '',
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String? ?? 'Khách vãng lai',
      guestPhone: map['guestPhone'] as String?,
      openedBy: map['openedBy'] as String? ?? '',
      openedByRole: map['openedByRole'] as String? ?? 'waiter',
      reservationId: map['reservationId'] as String?,
      startedAt: _parseDateTime(map['startedAt']),
      baseMinutes: (map['baseMinutes'] as num?)?.toInt() ?? 120,
      extendedMinutes: (map['extendedMinutes'] as num?)?.toInt() ?? 0,
      expiresAt: _parseDateTime(map['expiresAt']),
      extensions: (map['extensions'] as List<dynamic>?)
              ?.map((e) =>
                  SessionExtension.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      earlyReleased: map['earlyReleased'] as bool? ?? false,
      status: map['status'] as String? ?? 'active',
      subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tableId': tableId,
      'tableName': tableName,
      'customerId': customerId,
      'customerName': customerName,
      'guestPhone': guestPhone,
      'openedBy': openedBy,
      'openedByRole': openedByRole,
      'reservationId': reservationId,
      'startedAt': Timestamp.fromDate(startedAt),
      'baseMinutes': baseMinutes,
      'extendedMinutes': extendedMinutes,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'extensions': extensions.map((e) => e.toMap()).toList(),
      'earlyReleased': earlyReleased,
      'status': status,
      'subtotal': subtotal,
    };
  }

  SessionModel copyWith({
    String? id,
    String? tableId,
    String? tableName,
    String? customerId,
    String? customerName,
    String? guestPhone,
    String? openedBy,
    String? openedByRole,
    String? reservationId,
    DateTime? startedAt,
    int? baseMinutes,
    int? extendedMinutes,
    DateTime? expiresAt,
    List<SessionExtension>? extensions,
    bool? earlyReleased,
    String? status,
    int? subtotal,
  }) {
    return SessionModel(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      guestPhone: guestPhone ?? this.guestPhone,
      openedBy: openedBy ?? this.openedBy,
      openedByRole: openedByRole ?? this.openedByRole,
      reservationId: reservationId ?? this.reservationId,
      startedAt: startedAt ?? this.startedAt,
      baseMinutes: baseMinutes ?? this.baseMinutes,
      extendedMinutes: extendedMinutes ?? this.extendedMinutes,
      expiresAt: expiresAt ?? this.expiresAt,
      extensions: extensions ?? this.extensions,
      earlyReleased: earlyReleased ?? this.earlyReleased,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}

