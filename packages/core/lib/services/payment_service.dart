import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_config.dart';
import '../constants/enums.dart';
import '../models/payment_model.dart';
import '../models/reservation_model.dart';
import '../models/order_model.dart';
import '../models/session_model.dart';
import '../models/user_model.dart';
import 'clock_service.dart';

/// Kết quả tính toán trước hóa đơn thanh toán và các mức điểm thưởng/giảm trừ.
class PaymentCalculationResult {
  final int subtotal;
  final int pointsRequested;
  final int pointsUsed;
  final int discount;
  final int total;
  final int pointsEarned;
  final int bonusEarlyRelease;
  final int bonusPreOrder;
  final int totalBonusPoints;

  const PaymentCalculationResult({
    required this.subtotal,
    required this.pointsRequested,
    required this.pointsUsed,
    required this.discount,
    required this.total,
    required this.pointsEarned,
    required this.bonusEarlyRelease,
    required this.bonusPreOrder,
    required this.totalBonusPoints,
  });
}

/// Dịch vụ tính toán tiền thanh toán, áp dụng điểm thưởng, xuất hóa đơn và đóng bàn.
class PaymentService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  PaymentService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  /// Hàm thuần túy (Pure Function) tính toán số tiền thanh toán, giới hạn giảm giá
  /// tối đa 50% bằng điểm, và tính điểm thưởng (trả bàn sớm +20 điểm, đặt trước +10 điểm).
  ///
  /// Được sử dụng cho cả giao diện Checkout Modal và kiểm thử tự động (Unit Test).
  static PaymentCalculationResult calculatePayment({
    required int subtotal,
    int pointsUsed = 0,
    bool earlyReleased = false,
    bool hasPreOrder = false,
    AppConfig config = AppConfig.defaultConfig,
  }) {
    config.validate();
    if (subtotal < 0 || pointsUsed < 0)
      throw ArgumentError('Tiền và điểm không được âm.');
    // 1. Tính toán giảm giá từ điểm tích lũy
    final maxDiscountAllowed = (subtotal * config.maxRedeemPercent) ~/ 100;
    final actualPoints =
        min(pointsUsed, maxDiscountAllowed ~/ config.pointRedeemVnd);
    final actualDiscount = actualPoints * config.pointRedeemVnd;

    // Tính lại số điểm thực tế bị trừ
    final actualPointsUsed = actualDiscount ~/ config.pointRedeemVnd;

    // 2. Tính số tiền thực thu
    final total = max(0, subtotal - actualDiscount);

    // 3. Tính điểm tích lũy mới (10.000đ = 1 điểm)
    final pointsEarned = total ~/ config.pointEarnVnd;

    // 4. Tính điểm thưởng bổ sung
    final bonusEarlyRelease =
        earlyReleased ? config.earlyReleaseBonusPoints : 0;
    final bonusPreOrder = hasPreOrder ? config.preOrderBonusPoints : 0;
    final totalBonus = bonusEarlyRelease + bonusPreOrder;

    return PaymentCalculationResult(
      subtotal: subtotal,
      pointsRequested: pointsUsed,
      pointsUsed: actualPointsUsed,
      discount: actualDiscount,
      total: total,
      pointsEarned: pointsEarned,
      bonusEarlyRelease: bonusEarlyRelease,
      bonusPreOrder: bonusPreOrder,
      totalBonusPoints: totalBonus,
    );
  }

  /// Thanh toán bàn trong transaction; đọc trước khi ghi và chặn thanh toán lặp.
  Future<PaymentModel> payAndClose({
    required String sessionId,
    required String cashierId,
    required PaymentMethod method,
    String? customerId,
    int pointsUsed = 0,
    int? expectedSubtotal,
    AppConfig? expectedConfig,
  }) async {
    if (sessionId == 'takeaway_orders') {
      throw StateError('Hãy thanh toán từng đơn mang đi.');
    }
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final payRef = _firestore.collection('payments').doc();
    return _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(sessionRef);
      if (!snapshot.exists) throw StateError('Không tìm thấy phiên bàn.');
      final session = SessionModel.fromMap(snapshot.data()!, snapshot.id);
      if (session.status != 'active' && session.status != 'billing') {
        throw StateError('Phiên đã thanh toán hoặc đã hủy.');
      }
      final tableRef = _firestore.collection('tables').doc(session.tableId);
      final table = await tx.get(tableRef);
      if (!table.exists || table.data()?['currentSessionId'] != sessionId) {
        throw StateError('Bàn không còn thuộc phiên này. Vui lòng tải lại.');
      }
      final config = await _readConfig(tx);
      final query = await sessionRef.collection('orders').get();
      final orders = <OrderModel>[];
      for (final doc in query.docs) {
        final current = await tx.get(doc.reference);
        if (current.exists)
          orders.add(OrderModel.fromMap(current.data()!, current.id));
      }
      if (orders.any((order) => order.orderStatus == OrderStatus.pending)) {
        throw StateError(
            'Vẫn còn đơn chờ duyệt. Hãy duyệt hoặc từ chối trước khi thanh toán.');
      }
      final billable =
          orders.where((o) => o.orderStatus != OrderStatus.cancelled).toList();
      final subtotal = billable.fold<int>(0, (sum, o) => sum + o.total);
      _checkPreview(subtotal, config, expectedSubtotal, expectedConfig);
      bool hasPreOrder = false;
      bool reservationExists = false;
      final reservationId = session.reservationId;
      if (reservationId != null && reservationId.isNotEmpty) {
        final res = await tx
            .get(_firestore.collection('reservations').doc(reservationId));
        reservationExists = res.exists;
        if (res.exists)
          hasPreOrder =
              ReservationModel.fromMap(res.data()!, res.id).hasPreOrder;
      }
      final slotRefs = <DocumentReference<Map<String, dynamic>>>[];
      if (reservationId != null && reservationId.isNotEmpty) {
        final slots = await tableRef
            .collection('slots')
            .where('reservationId', isEqualTo: reservationId)
            .get();
        for (final doc in slots.docs) {
          final slot = await tx.get(doc.reference);
          if (slot.data()?['reservationId'] == reservationId)
            slotRefs.add(doc.reference);
        }
      }
      final rawMemberUid = customerId ?? session.customerId;
      final memberUid =
          rawMemberUid == null || rawMemberUid.isEmpty ? null : rawMemberUid;
      final member = await _readMember(tx, memberUid, pointsUsed);
      final calc = calculatePayment(
          subtotal: subtotal,
          pointsUsed: pointsUsed,
          earlyReleased: session.earlyReleased,
          hasPreOrder: hasPreOrder,
          config: config);
      _checkPoints(member, calc);
      final payment = _makePayment(payRef.id, sessionId, session.tableId,
          session.tableName, cashierId, method, memberUid, calc);
      // Không đọc thêm sau thời điểm bắt đầu ghi transaction.
      _writePoints(tx, member, payment, calc);
      tx.set(payRef, {
        ...payment.toMap(),
        'items': billable.expand((o) => o.items).map((i) => i.toMap()).toList()
      });
      tx.update(sessionRef, {'status': 'paid', 'subtotal': subtotal});
      tx.update(
          tableRef, {'status': 'needs_cleaning', 'currentSessionId': null});
      for (final ref in slotRefs) {
        tx.delete(ref);
      }
      if (reservationExists) {
        tx.update(_firestore.collection('reservations').doc(reservationId),
            {'status': 'completed'});
      }
      return payment;
    });
  }

  /// Thu tiền một đơn mang đi riêng biệt; không đóng bàn, không cộng thưởng đặt bàn.
  Future<PaymentModel> payTakeaway({
    required String orderId,
    required String cashierId,
    required PaymentMethod method,
    String? customerId,
    int pointsUsed = 0,
    int? expectedSubtotal,
    AppConfig? expectedConfig,
  }) async {
    final orderRef = _firestore
        .collection('sessions')
        .doc('takeaway_orders')
        .collection('orders')
        .doc(orderId);
    final payRef = _firestore.collection('payments').doc('takeaway_$orderId');
    return _firestore.runTransaction((tx) async {
      final doc = await tx.get(orderRef);
      final existing = await tx.get(payRef);
      if (!doc.exists) throw StateError('Không tìm thấy đơn mang đi.');
      if (existing.exists || doc.data()?['paymentId'] != null) {
        throw StateError('Đơn mang đi đã được thanh toán.');
      }
      final order = OrderModel.fromMap(doc.data()!, doc.id);
      if (order.orderType != OrderType.takeaway ||
          ![OrderStatus.ready, OrderStatus.served]
              .contains(order.orderStatus)) {
        throw StateError(
            'Chỉ thanh toán đơn mang đi đã sẵn sàng hoặc đã phục vụ.');
      }
      final config = await _readConfig(tx);
      _checkPreview(order.total, config, expectedSubtotal, expectedConfig);
      final memberUid =
          customerId == null || customerId.isEmpty ? null : customerId;
      final member = await _readMember(tx, memberUid, pointsUsed);
      final calc = calculatePayment(
          subtotal: order.total, pointsUsed: pointsUsed, config: config);
      _checkPoints(member, calc);
      final payment = _makePayment(payRef.id, 'takeaway_orders', 'takeaway',
          order.tableName, cashierId, method, memberUid, calc);
      _writePoints(tx, member, payment, calc);
      tx.set(payRef, {
        ...payment.toMap(),
        'orderId': orderId,
        'items': order.items.map((i) => i.toMap()).toList()
      });
      tx.update(orderRef, {
        'paymentId': payment.id,
        'updatedAt': Timestamp.fromDate(payment.paidAt)
      });
      return payment;
    });
  }

  Future<AppConfig> _readConfig(Transaction tx) async {
    final doc = await tx.get(_firestore.collection('config').doc('app'));
    final config = AppConfig.fromMap(doc.data() ?? {});
    config.validate();
    return config;
  }

  void _checkPreview(int subtotal, AppConfig config, int? expectedSubtotal,
      AppConfig? expectedConfig) {
    if (expectedSubtotal != null && expectedSubtotal != subtotal) {
      throw StateError(
          'Đơn hàng đã thay đổi. Hãy đóng và mở lại thanh toán để kiểm tra số tiền.');
    }
    if (expectedConfig != null) {
      final current = config.toMap();
      final expected = expectedConfig.toMap();
      if ([
        'pointEarnVnd',
        'pointRedeemVnd',
        'maxRedeemPercent',
        'earlyReleaseBonusPoints',
        'preOrderBonusPoints'
      ].any((key) => current[key] != expected[key])) {
        throw StateError(
            'Cấu hình tính tiền vừa thay đổi. Vui lòng kiểm tra lại và xác nhận lần nữa.');
      }
    }
  }

  Future<UserModel?> _readMember(
      Transaction tx, String? uid, int points) async {
    if (uid == null || uid.isEmpty) {
      if (points > 0) throw StateError('Cần chọn thành viên để đổi điểm.');
      return null;
    }
    final doc = await tx.get(_firestore.collection('users').doc(uid));
    if (!doc.exists) throw StateError('Không tìm thấy thành viên.');
    final user = UserModel.fromMap(doc.data()!, doc.id);
    if (user.userRole != UserRole.customer)
      throw StateError('Tài khoản không phải khách hàng.');
    return user;
  }

  void _checkPoints(UserModel? member, PaymentCalculationResult calc) {
    if (member != null && member.points < calc.pointsUsed) {
      throw StateError('Thành viên không đủ điểm. Vui lòng tải lại thông tin.');
    }
  }

  PaymentModel _makePayment(
          String id,
          String sessionId,
          String tableId,
          String tableName,
          String cashierId,
          PaymentMethod method,
          String? customerId,
          PaymentCalculationResult calc) =>
      PaymentModel(
        id: id,
        sessionId: sessionId,
        tableId: tableId,
        tableName: tableName,
        cashierId: cashierId,
        method: method.name,
        subtotal: calc.subtotal,
        pointsUsed: calc.pointsUsed,
        discount: calc.discount,
        total: calc.total,
        pointsEarned: customerId == null ? 0 : calc.pointsEarned,
        bonusPoints: customerId == null ? 0 : calc.totalBonusPoints,
        customerId: customerId,
        paidAt: ClockService.instance.serverNow,
      );

  void _writePoints(Transaction tx, UserModel? member, PaymentModel payment,
      PaymentCalculationResult calc) {
    if (member == null) return;
    final ref = _firestore.collection('users').doc(member.id);
    tx.update(ref, {
      'points': member.points -
          calc.pointsUsed +
          calc.pointsEarned +
          calc.totalBonusPoints
    });
    final changes = {
      'redeem': -calc.pointsUsed,
      'earn': calc.pointsEarned,
      'bonus_early_release': calc.bonusEarlyRelease,
      'bonus_preorder': calc.bonusPreOrder
    };
    for (final entry in changes.entries.where((e) => e.value != 0)) {
      tx.set(ref.collection('pointTx').doc(), {
        'type': entry.key,
        'points': entry.value,
        'sessionId': payment.sessionId,
        'paymentId': payment.id,
        'at': Timestamp.fromDate(payment.paidAt)
      });
    }
  }

  /// Các món đã chốt trên hóa đơn, phục vụ xem lại biên lai mà không lấy đơn bị hủy.
  Future<List<OrderItemModel>> getPaymentItems(String paymentId) async {
    final doc = await _firestore.collection('payments').doc(paymentId).get();
    return (doc.data()?['items'] as List<dynamic>? ?? [])
        .map((item) =>
            OrderItemModel.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Lắng nghe hóa đơn của một phiên bàn cụ thể.
  Stream<PaymentModel?> watchSessionPayment(String sessionId) {
    return _firestore
        .collection('payments')
        .where('sessionId', isEqualTo: sessionId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return PaymentModel.fromMap(doc.data(), doc.id);
    });
  }

  /// Lắng nghe các hóa đơn thanh toán phát sinh trong ngày hôm nay.
  Stream<List<PaymentModel>> watchTodayPayments() {
    final now = ClockService.instance.serverNow;
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _firestore
        .collection('payments')
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('paidAt',
            isLessThan:
                Timestamp.fromDate(startOfDay.add(const Duration(days: 1))))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
