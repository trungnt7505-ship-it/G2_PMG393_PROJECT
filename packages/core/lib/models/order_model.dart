import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

/// Tùy chọn được chọn kèm theo món (Topping, Size...).
class SelectedOption {
  final String groupName;
  final String choiceName;
  final int extraPrice;

  const SelectedOption({
    required this.groupName,
    required this.choiceName,
    this.extraPrice = 0,
  });

  factory SelectedOption.fromMap(Map<String, dynamic> map) {
    return SelectedOption(
      groupName: map['groupName'] as String? ?? '',
      choiceName: map['choiceName'] as String? ?? '',
      extraPrice: (map['extraPrice'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupName': groupName,
      'choiceName': choiceName,
      'extraPrice': extraPrice,
    };
  }

  SelectedOption copyWith({
    String? groupName,
    String? choiceName,
    int? extraPrice,
  }) {
    return SelectedOption(
      groupName: groupName ?? this.groupName,
      choiceName: choiceName ?? this.choiceName,
      extraPrice: extraPrice ?? this.extraPrice,
    );
  }
}

/// Chi tiết một món trong đơn gọi món hoặc đơn đặt trước (Pre-order).
class OrderItemModel {
  /// Mã món gốc từ menuItems.
  final String itemId;

  /// Tên món tại thời điểm đặt.
  final String name;

  /// Đơn giá cơ bản VND tại thời điểm đặt.
  final int unitPrice;

  /// Số lượng đặt.
  final int qty;

  /// Danh sách các tùy chọn đã chọn (Size, Topping...).
  final List<SelectedOption> selectedOptions;

  /// Ghi chú của khách (VD: "Ít ngọt, nhiều đá").
  final String? note;

  const OrderItemModel({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.qty,
    this.selectedOptions = const [],
    this.note,
  });

  /// Tính thành tiền của món (bao gồm cả giá phụ thu từ các tùy chọn).
  int get totalPrice {
    final extra = selectedOptions.fold<int>(0, (sum, opt) => sum + opt.extraPrice);
    return (unitPrice + extra) * qty;
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      itemId: map['itemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toInt() ?? 0,
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      selectedOptions: (map['selectedOptions'] as List<dynamic>?)
              ?.map((e) =>
                  SelectedOption.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'unitPrice': unitPrice,
      'qty': qty,
      'selectedOptions': selectedOptions.map((e) => e.toMap()).toList(),
      'note': note,
    };
  }

  OrderItemModel copyWith({
    String? itemId,
    String? name,
    int? unitPrice,
    int? qty,
    List<SelectedOption>? selectedOptions,
    String? note,
  }) {
    return OrderItemModel(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      qty: qty ?? this.qty,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      note: note ?? this.note,
    );
  }
}

/// Đơn gọi món trong phiên hoặc mang đi.
/// Firestore path: `sessions/{sessionId}/orders/{orderId}` hoặc `takeawayOrders/{orderId}`.
class OrderModel {
  /// Mã định danh đơn hàng.
  final String id;

  /// Mã phiên bàn liên kết.
  final String sessionId;

  /// Mã bàn.
  final String tableId;

  /// Tên bàn hiển thị.
  final String tableName;

  /// Danh sách các món trong đơn này.
  final List<OrderItemModel> items;

  /// UID người tạo đơn (Khách hàng hoặc Phục vụ/Thu ngân).
  final String createdBy;

  /// Vai trò người tạo đơn ('customer', 'waiter', 'counter').
  final String createdByRole;

  /// Hình thức: 'dine_in' hoặc 'takeaway'.
  final String type;

  /// Trạng thái: 'pending', 'confirmed', 'preparing', 'ready', 'served', 'cancelled'.
  final String status;

  /// Lý do từ chối/hủy đơn (nếu có).
  final String? cancelReason;

  /// Tổng tiền của cả đơn hàng (VND).
  final int total;

  /// Thời điểm tạo đơn.
  final DateTime createdAt;

  /// Thời điểm cập nhật trạng thái gần nhất.
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.sessionId,
    required this.tableId,
    required this.tableName,
    required this.items,
    required this.createdBy,
    required this.createdByRole,
    this.type = 'dine_in',
    this.status = 'pending',
    this.cancelReason,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Chuyển đổi trạng thái đơn sang [OrderStatus].
  OrderStatus get orderStatus => OrderStatus.fromString(status);

  /// Chuyển đổi loại đơn sang [OrderType].
  OrderType get orderType => OrderType.fromString(type);

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      sessionId: map['sessionId'] as String? ?? '',
      tableId: map['tableId'] as String? ?? '',
      tableName: map['tableName'] as String? ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) =>
                  OrderItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      createdBy: map['createdBy'] as String? ?? '',
      createdByRole: map['createdByRole'] as String? ?? 'customer',
      type: map['type'] as String? ?? 'dine_in',
      status: map['status'] as String? ?? 'pending',
      cancelReason: map['cancelReason'] as String?,
      total: (map['total'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'tableId': tableId,
      'tableName': tableName,
      'items': items.map((e) => e.toMap()).toList(),
      'createdBy': createdBy,
      'createdByRole': createdByRole,
      'type': type,
      'status': status,
      'cancelReason': cancelReason,
      'total': total,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OrderModel copyWith({
    String? id,
    String? sessionId,
    String? tableId,
    String? tableName,
    List<OrderItemModel>? items,
    String? createdBy,
    String? createdByRole,
    String? type,
    String? status,
    String? cancelReason,
    int? total,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      items: items ?? this.items,
      createdBy: createdBy ?? this.createdBy,
      createdByRole: createdByRole ?? this.createdByRole,
      type: type ?? this.type,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

