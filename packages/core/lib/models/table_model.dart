import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/enums.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

/// Thông tin bàn trong quán Cafe.
/// Firestore path: `tables/{tableId}`.
class TableModel {
  /// Mã định danh bàn (VD: "table_01").
  final String id;

  /// Tên bàn hiển thị (VD: "Bàn 01").
  final String name;

  /// Khu vực bố trí (VD: "Tầng 1", "Tầng 2", "Ngoài trời").
  final String zone;

  /// Sức chứa số lượng khách tối đa của bàn.
  final int capacity;

  /// Trạng thái vật lý lưu Firestore: 'available', 'occupied', 'needs_cleaning'.
  final String status;

  /// Mã phiên sử dụng hiện tại (nếu bàn đang occupied).
  final String? currentSessionId;

  /// Mã bí mật để xác thực khi quét mã QR dán tại bàn.
  final String qrSecret;

  const TableModel({
    required this.id,
    required this.name,
    required this.zone,
    required this.capacity,
    this.status = 'available',
    this.currentSessionId,
    required this.qrSecret,
  });

  /// Chuyển đổi trạng thái string sang [TablePhysicalStatus].
  TablePhysicalStatus get physicalStatus =>
      TablePhysicalStatus.fromString(status);

  /// Chuỗi URI mã QR dán tại bàn theo chuẩn thiết kế: `cafe://table/{tableId}?k={qrSecret}`.
  String get qrUrl => 'cafe://table/$id?k=$qrSecret';

  /// Khởi tạo TableModel từ Firestore Document Map.
  factory TableModel.fromMap(Map<String, dynamic> map, String id) {
    return TableModel(
      id: id,
      name: map['name'] as String? ?? '',
      zone: map['zone'] as String? ?? '',
      capacity: (map['capacity'] as num?)?.toInt() ?? 2,
      status: map['status'] as String? ?? 'available',
      currentSessionId: map['currentSessionId'] as String?,
      qrSecret: map['qrSecret'] as String? ?? '',
    );
  }

  /// Chuyển đối tượng thành Map để lưu trữ trên Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'zone': zone,
      'capacity': capacity,
      'status': status,
      'currentSessionId': currentSessionId,
      'qrSecret': qrSecret,
    };
  }

  /// Tạo bản sao có cập nhật thuộc tính.
  TableModel copyWith({
    String? id,
    String? name,
    String? zone,
    int? capacity,
    String? status,
    String? currentSessionId,
    String? qrSecret,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      zone: zone ?? this.zone,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      qrSecret: qrSecret ?? this.qrSecret,
    );
  }
}

/// Khung giờ đặt trước (Slot) để giữ bàn chống trùng lịch.
/// Mỗi lượt đặt bàn giữ 5 slot liên tiếp cách nhau 30 phút (tổng cộng 150 phút).
/// Firestore path: `tables/{tableId}/slots/{yyyyMMddHHmm}`.
class TableSlotModel {
  /// Khóa định dạng yyyyMMddHHmm (VD: "202610141430").
  final String id;

  /// Mã đơn đặt trước đang giữ khung giờ này.
  final String reservationId;

  /// Thời điểm bắt đầu của slot đặt trước.
  final DateTime resStart;

  const TableSlotModel({
    required this.id,
    required this.reservationId,
    required this.resStart,
  });

  /// Định dạng DateTime thành chuỗi slot key `yyyyMMddHHmm`.
  static String formatSlotKey(DateTime dt) {
    return DateFormat('yyyyMMddHHmm').format(dt);
  }

  /// Sinh đúng 5 mốc thời gian giữ chỗ liên tiếp (bước nhảy 30 phút = 150 phút).
  /// Mốc 1: `start`
  /// Mốc 2: `start + 30 phút`
  /// Mốc 3: `start + 60 phút`
  /// Mốc 4: `start + 90 phút`
  /// Mốc 5: `start + 120 phút`
  static List<DateTime> slotTimes(DateTime start) {
    return List.generate(5, (index) => start.add(Duration(minutes: index * 30)));
  }

  /// Sinh danh sách 5 khóa slot dạng `yyyyMMddHHmm` cho một thời điểm bắt đầu.
  static List<String> generateSlotKeys(DateTime start) {
    return slotTimes(start).map((t) => formatSlotKey(t)).toList();
  }

  /// Khởi tạo TableSlotModel từ Firestore Map.
  factory TableSlotModel.fromMap(Map<String, dynamic> map, String id) {
    return TableSlotModel(
      id: id,
      reservationId: map['reservationId'] as String? ?? '',
      resStart: _parseDateTime(map['resStart']),
    );
  }

  /// Chuyển đối tượng thành Map để lưu trữ trên Firestore.
  Map<String, dynamic> toMap() {
    return {
      'reservationId': reservationId,
      'resStart': Timestamp.fromDate(resStart),
    };
  }

  /// Tạo bản sao có cập nhật thuộc tính.
  TableSlotModel copyWith({
    String? id,
    String? reservationId,
    DateTime? resStart,
  }) {
    return TableSlotModel(
      id: id ?? this.id,
      reservationId: reservationId ?? this.reservationId,
      resStart: resStart ?? this.resStart,
    );
  }
}

