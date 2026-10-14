import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/enums.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import 'clock_service.dart';

/// Dịch vụ quản lý đơn gọi món, hàng đợi pha chế và trạng thái phục vụ.
class OrderService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  OrderService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  /// Đặt đơn gọi món mới.
  ///
  /// Quy tắc:
  /// - Đọc lại thông tin từng món từ `menuItems` để xác thực `available == true` và chốt đúng giá từ server.
  /// - Nếu khách tự đặt (`createdByRole == 'customer'`) -> Đơn có trạng thái `pending` (chờ nhân viên duyệt).
  /// - Nếu nhân viên hoặc quầy tạo -> Đơn có trạng thái `confirmed` và cộng ngay giá trị đơn vào `sessions.subtotal`.
  Future<String> submitOrder({
    required String sessionId,
    required String tableId,
    required String tableName,
    required List<OrderItemModel> items,
    required String createdBy,
    required String createdByRole,
    OrderType type = OrderType.dine_in,
  }) async {
    if (items.isEmpty) {
      throw Exception('Đơn hàng không có món nào.');
    }

    final now = ClockService.instance.serverNow;

    // 1. Kiểm tra tính khả dụng và tính lại giá chuẩn từ Firestore
    final validatedItems = <OrderItemModel>[];
    int calculatedTotal = 0;

    for (final item in items) {
      final itemDoc = await _firestore.collection('menuItems').doc(item.itemId).get();
      if (!itemDoc.exists || itemDoc.data() == null) {
        throw Exception('Món "${item.name}" không tồn tại trên thực đơn.');
      }

      final menuItem = MenuItemModel.fromMap(itemDoc.data()!, itemDoc.id);
      if (!menuItem.available) {
        throw Exception('Món "${menuItem.name}" hiện đang tạm hết hàng.');
      }

      // Xác thực giá chuẩn
      final validatedItem = item.copyWith(
        unitPrice: menuItem.price,
      );
      validatedItems.add(validatedItem);
      calculatedTotal += validatedItem.totalPrice;
    }

    final isStaff = createdByRole != 'customer';
    final initialStatus = isStaff ? OrderStatus.confirmed : OrderStatus.pending;

    return await _firestore.runTransaction<String>((transaction) async {
      final orderRef = _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('orders')
          .doc();

      final order = OrderModel(
        id: orderRef.id,
        sessionId: sessionId,
        tableId: tableId,
        tableName: tableName,
        items: validatedItems,
        createdBy: createdBy,
        createdByRole: createdByRole,
        type: type.name,
        status: initialStatus.name,
        total: calculatedTotal,
        createdAt: now,
        updatedAt: now,
      );

      transaction.set(orderRef, order.toMap());

      // Nếu nhân viên tạo đơn, cộng ngay vào subtotal của phiên bàn
      if (isStaff && sessionId != 'takeaway_orders') {
        final sessionRef = _firestore.collection('sessions').doc(sessionId);
        final sessionSnapshot = await transaction.get(sessionRef);
        if (sessionSnapshot.exists && sessionSnapshot.data() != null) {
          final currentSubtotal = (sessionSnapshot.data()?['subtotal'] as num?)?.toInt() ?? 0;
          transaction.update(sessionRef, {
            'subtotal': currentSubtotal + calculatedTotal,
          });
        }
      }

      return orderRef.id;
    });
  }

  /// Nhân viên duyệt đơn gọi món của khách: chuyển từ `pending` sang `confirmed`
  /// và cộng tiền đơn hàng vào `sessions.subtotal`.
  Future<void> approveOrder(String sessionId, String orderId) async {
    final now = ClockService.instance.serverNow;

    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('orders')
          .doc(orderId);

      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists || orderSnapshot.data() == null) {
        throw Exception('Không tìm thấy đơn hàng cần duyệt.');
      }

      final order = OrderModel.fromMap(orderSnapshot.data()!, orderSnapshot.id);
      if (order.orderStatus != OrderStatus.pending) {
        throw Exception('Chỉ có thể duyệt đơn hàng đang ở trạng thái chờ duyệt (pending).');
      }

      transaction.update(orderRef, {
        'status': OrderStatus.confirmed.name,
        'updatedAt': Timestamp.fromDate(now),
      });

      if (sessionId != 'takeaway_orders') {
        final sessionRef = _firestore.collection('sessions').doc(sessionId);
        final sessionSnapshot = await transaction.get(sessionRef);
        if (sessionSnapshot.exists && sessionSnapshot.data() != null) {
          final currentSubtotal = (sessionSnapshot.data()?['subtotal'] as num?)?.toInt() ?? 0;
          transaction.update(sessionRef, {
            'subtotal': currentSubtotal + order.total,
          });
        }
      }
    });
  }

  /// Hủy đơn gọi món. Nếu đơn đã được xác nhận trước đó thì trừ lại tiền trong `sessions.subtotal`.
  Future<void> cancelOrder(
    String sessionId,
    String orderId, {
    required String reason,
  }) async {
    final now = ClockService.instance.serverNow;

    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('orders')
          .doc(orderId);

      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists || orderSnapshot.data() == null) {
        throw Exception('Không tìm thấy đơn hàng cần hủy.');
      }

      final order = OrderModel.fromMap(orderSnapshot.data()!, orderSnapshot.id);
      if (order.orderStatus == OrderStatus.cancelled) {
        return; // Đã hủy từ trước
      }

      final wasCountedInSubtotal = order.orderStatus != OrderStatus.pending;

      transaction.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'cancelReason': reason,
        'updatedAt': Timestamp.fromDate(now),
      });

      if (wasCountedInSubtotal && sessionId != 'takeaway_orders') {
        final sessionRef = _firestore.collection('sessions').doc(sessionId);
        final sessionSnapshot = await transaction.get(sessionRef);
        if (sessionSnapshot.exists && sessionSnapshot.data() != null) {
          final currentSubtotal = (sessionSnapshot.data()?['subtotal'] as num?)?.toInt() ?? 0;
          final updatedSubtotal = (currentSubtotal - order.total).clamp(0, double.infinity).toInt();
          transaction.update(sessionRef, {
            'subtotal': updatedSubtotal,
          });
        }
      }
    });
  }

  /// Cập nhật tiến độ pha chế / phục vụ món (`confirmed` -> `preparing` -> `ready` -> `served`).
  Future<void> updatePreparationStatus(
    String sessionId,
    String orderId,
    OrderStatus newStatus,
  ) async {
    final now = ClockService.instance.serverNow;
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('orders')
        .doc(orderId)
        .update({
      'status': newStatus.name,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Lắng nghe danh sách tất cả các đơn gọi món của một phiên bàn theo thời gian thực.
  Stream<List<OrderModel>> watchSessionOrders(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Lắng nghe tất cả các đơn hàng trên toàn hệ thống có trạng thái nằm trong danh sách [statuses].
  /// Sử dụng collectionGroup('orders') để phục vụ màn hình Quầy pha chế (KDS) và Quản lý.
  Stream<List<OrderModel>> watchAllOrdersByStatuses(List<OrderStatus> statuses) {
    if (statuses.isEmpty) {
      return Stream.value([]);
    }

    final statusStrings = statuses.map((e) => e.name).toList();

    return _firestore
        .collectionGroup('orders')
        .where('status', whereIn: statusStrings)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Quản lý bật/tắt trạng thái khả dụng của món trên thực đơn (dành cho Quản lý).
  Future<void> toggleMenuItemAvailability(String itemId, bool isAvailable) async {
    await _firestore.collection('menuItems').doc(itemId).update({
      'available': isAvailable,
    });
  }
}
