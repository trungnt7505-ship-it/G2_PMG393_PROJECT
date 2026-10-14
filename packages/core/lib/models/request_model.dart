import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

/// Yêu cầu hỗ trợ từ bàn gửi đến nhân viên phục vụ / quầy thu ngân.
/// Firestore path: `requests/{reqId}`.
class RequestModel {
  /// Mã yêu cầu.
  final String id;

  /// Mã phiên bàn gửi yêu cầu.
  final String sessionId;

  /// Mã bàn.
  final String tableId;

  /// Tên bàn hiển thị.
  final String tableName;

  /// Loại yêu cầu: 'call_waiter', 'request_bill', 'release_table', 'early_release'.
  final String type;

  /// Lời nhắn kèm theo của khách hàng hoặc nhân viên.
  final String message;

  /// Trạng thái xử lý: 'open' (chưa giải quyết), 'done' (đã xử lý xong).
  final String status;

  /// UID người tạo yêu cầu (khách hàng hoặc nhân viên).
  final String createdBy;

  /// Thời điểm gửi yêu cầu.
  final DateTime createdAt;

  const RequestModel({
    required this.id,
    required this.sessionId,
    required this.tableId,
    required this.tableName,
    required this.type,
    this.message = '',
    this.status = 'open',
    required this.createdBy,
    required this.createdAt,
  });

  /// Chuyển đổi loại yêu cầu sang [RequestType].
  RequestType get requestType => RequestType.fromString(type);

  /// Kiểm tra xem yêu cầu có đang chờ xử lý hay không.
  bool get isOpen => status == 'open';

  factory RequestModel.fromMap(Map<String, dynamic> map, String id) {
    return RequestModel(
      id: id,
      sessionId: map['sessionId'] as String? ?? '',
      tableId: map['tableId'] as String? ?? '',
      tableName: map['tableName'] as String? ?? '',
      type: map['type'] as String? ?? 'call_waiter',
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'tableId': tableId,
      'tableName': tableName,
      'type': type,
      'message': message,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  RequestModel copyWith({
    String? id,
    String? sessionId,
    String? tableId,
    String? tableName,
    String? type,
    String? message,
    String? status,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return RequestModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      type: type ?? this.type,
      message: message ?? this.message,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

