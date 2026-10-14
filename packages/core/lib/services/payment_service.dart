import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_config.dart';
import '../constants/enums.dart';
import '../models/payment_model.dart';
import '../models/reservation_model.dart';
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
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  PaymentService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

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
    // 1. Tính toán giảm giá từ điểm tích lũy
    final discountByPoints = pointsUsed * config.pointRedeemVnd;
    final maxDiscountAllowed = (subtotal * config.maxRedeemPercent) ~/ 100;
    final actualDiscount = min(discountByPoints, maxDiscountAllowed);

    // Tính lại số điểm thực tế bị trừ
    final actualPointsUsed = actualDiscount ~/ config.pointRedeemVnd;

    // 2. Tính số tiền thực thu
    final total = max(0, subtotal - actualDiscount);

    // 3. Tính điểm tích lũy mới (10.000đ = 1 điểm)
    final pointsEarned = total ~/ config.pointEarnVnd;

    // 4. Tính điểm thưởng bổ sung
    final bonusEarlyRelease = earlyReleased ? config.earlyReleaseBonusPoints : 0;
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

  /// Thực hiện thanh toán và đóng phiên bàn (Checkout & Close Session).
  ///
  /// Thực hiện trong Firestore Transaction:
  /// 1. Kiểm tra không còn đơn gọi món nào đang ở trạng thái `pending`.
  /// 2. Tính tiền thực thu, giảm giá điểm (tối đa 50%), cộng điểm tích lũy và thưởng.
  /// 3. Tạo tài liệu `payments/{payId}`.
  /// 4. Nếu có khách hàng thành viên: Cập nhật điểm và ghi log `users/{uid}/pointTx`.
  /// 5. Đổi trạng thái phiên sang `paid`.
  /// 6. Đổi trạng thái bàn sang `needs_cleaning`, gỡ `currentSessionId`.
  /// 7. Giải phóng các slot đặt trước của phiên này (nếu có).
  Future<PaymentModel> payAndClose({
    required String sessionId,
    required String cashierId,
    required PaymentMethod method,
    String? customerId,
    int pointsUsed = 0,
  }) async {
    final now = ClockService.instance.serverNow;

    return await _firestore.runTransaction<PaymentModel>((transaction) async {
      // 1. Kiểm tra đơn pending
      final pendingOrdersQuery = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('orders')
          .where('status', isEqualTo: OrderStatus.pending.name)
          .limit(1)
          .get();

      if (pendingOrdersQuery.docs.isNotEmpty) {
        throw Exception(
          'Vẫn còn đơn gọi món đang chờ duyệt. Vui lòng duyệt hoặc từ chối trước khi thanh toán.',
        );
      }

      // 2. Đọc thông tin phiên bàn
      final sessionRef = _firestore.collection('sessions').doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists || sessionSnapshot.data() == null) {
        throw Exception('Không tìm thấy thông tin phiên bàn.');
      }

      final session = SessionModel.fromMap(sessionSnapshot.data()!, sessionSnapshot.id);

      // Kiểm tra có đơn đặt trước kèm theo không
      bool hasPreOrder = false;
      if (session.reservationId != null && session.reservationId!.isNotEmpty) {
        final resDoc = await _firestore
            .collection('reservations')
            .doc(session.reservationId)
            .get();
        if (resDoc.exists && resDoc.data() != null) {
          final res = ReservationModel.fromMap(resDoc.data()!, resDoc.id);
          hasPreOrder = res.hasPreOrder;
        }
      }

      // 3. Tính toán tiền và điểm
      final calc = calculatePayment(
        subtotal: session.subtotal,
        pointsUsed: pointsUsed,
        earlyReleased: session.earlyReleased,
        hasPreOrder: hasPreOrder,
      );

      final memberUid = customerId ?? session.customerId;

      // 4. Nếu có khách hàng thành viên, kiểm tra và cập nhật điểm
      if (memberUid != null && memberUid.isNotEmpty) {
        final userRef = _firestore.collection('users').doc(memberUid);
        final userSnapshot = await transaction.get(userRef);

        if (userSnapshot.exists && userSnapshot.data() != null) {
          final user = UserModel.fromMap(userSnapshot.data()!, userSnapshot.id);
          if (user.points < calc.pointsUsed) {
            throw Exception(
              'Khách hàng chỉ có ${user.points} điểm, không đủ để đổi ${calc.pointsUsed} điểm.',
            );
          }

          final updatedPoints = user.points - calc.pointsUsed + calc.pointsEarned + calc.totalBonusPoints;
          transaction.update(userRef, {'points': updatedPoints});

          // Ghi lịch sử giao dịch điểm (pointTx)
          if (calc.pointsUsed > 0) {
            final txRef = userRef.collection('pointTx').doc();
            transaction.set(txRef, {
              'type': 'redeem',
              'points': -calc.pointsUsed,
              'sessionId': sessionId,
              'at': Timestamp.fromDate(now),
            });
          }

          if (calc.pointsEarned > 0) {
            final txRef = userRef.collection('pointTx').doc();
            transaction.set(txRef, {
              'type': 'earn',
              'points': calc.pointsEarned,
              'sessionId': sessionId,
              'at': Timestamp.fromDate(now),
            });
          }

          if (calc.bonusEarlyRelease > 0) {
            final txRef = userRef.collection('pointTx').doc();
            transaction.set(txRef, {
              'type': 'bonus_early_release',
              'points': calc.bonusEarlyRelease,
              'sessionId': sessionId,
              'at': Timestamp.fromDate(now),
            });
          }

          if (calc.bonusPreOrder > 0) {
            final txRef = userRef.collection('pointTx').doc();
            transaction.set(txRef, {
              'type': 'bonus_preorder',
              'points': calc.bonusPreOrder,
              'sessionId': sessionId,
              'at': Timestamp.fromDate(now),
            });
          }
        }
      }

      // 5. Tạo hóa đơn thanh toán
      final payRef = _firestore.collection('payments').doc();
      final payment = PaymentModel(
        id: payRef.id,
        sessionId: sessionId,
        tableId: session.tableId,
        tableName: session.tableName,
        cashierId: cashierId,
        method: method.name,
        subtotal: calc.subtotal,
        pointsUsed: calc.pointsUsed,
        discount: calc.discount,
        total: calc.total,
        pointsEarned: calc.pointsEarned,
        bonusPoints: calc.totalBonusPoints,
        customerId: memberUid,
        paidAt: now,
      );

      transaction.set(payRef, payment.toMap());

      // 6. Cập nhật phiên bàn sang paid
      transaction.update(sessionRef, {
        'status': SessionStatus.paid.name,
      });

      // 7. Chuyển bàn sang needs_cleaning và gỡ currentSessionId
      if (session.tableId.isNotEmpty && session.tableId != 'takeaway') {
        final tableRef = _firestore.collection('tables').doc(session.tableId);
        transaction.update(tableRef, {
          'status': TablePhysicalStatus.needs_cleaning.name,
          'currentSessionId': null,
        });

        // Giải phóng các slot tương lai liên kết với reservation này
        if (session.reservationId != null) {
          final slotsQuery = await _firestore
              .collection('tables')
              .doc(session.tableId)
              .collection('slots')
              .where('reservationId', isEqualTo: session.reservationId)
              .get();

          for (final doc in slotsQuery.docs) {
            transaction.delete(doc.reference);
          }
        }
      }

      return payment;
    });
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
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
