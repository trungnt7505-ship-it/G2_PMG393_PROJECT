import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation_model.dart';
import '../models/table_model.dart';
import 'clock_service.dart';

/// Dịch vụ quản lý đặt bàn trước (Pre-order / Reservation) và khóa khung giờ (Slots).
class ReservationService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  ReservationService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  /// Lấy danh sách các bàn còn trống thỏa mãn số lượng khách [partySize]
  /// tại thời điểm bắt đầu [startTime] (kiểm tra không bị trùng bất kỳ ô nào
  /// trong 5 slot liên tiếp cách nhau 30 phút).
  Future<List<TableModel>> getAvailableTables({
    required DateTime startTime,
    required int partySize,
  }) async {
    // 1. Lọc tất cả các bàn có sức chứa phù hợp
    final tableQuery = await _firestore
        .collection('tables')
        .where('capacity', isGreaterThanOrEqualTo: partySize)
        .get();

    final allTables = tableQuery.docs
        .map((doc) => TableModel.fromMap(doc.data(), doc.id))
        .toList();

    if (allTables.isEmpty) return [];

    final slotKeys = TableSlotModel.generateSlotKeys(startTime);
    final availableTables = <TableModel>[];

    // 2. Kiểm tra xung đột slot cho từng bàn
    for (final table in allTables) {
      bool isConflict = false;
      for (final key in slotKeys) {
        final slotDoc = await _firestore
            .collection('tables')
            .doc(table.id)
            .collection('slots')
            .doc(key)
            .get();

        if (slotDoc.exists) {
          isConflict = true;
          break;
        }
      }

      if (!isConflict) {
        availableTables.add(table);
      }
    }

    return availableTables;
  }

  /// Tạo đơn đặt bàn trước và khóa 5 slot liên tiếp cách nhau 30 phút (150 phút).
  /// Sử dụng Firestore Transaction để đảm bảo tính toàn vẹn, chống đặt trùng bàn.
  Future<String> createReservation(ReservationModel draft) async {
    final slotTimes = TableSlotModel.slotTimes(draft.startTime);
    final slotKeys = TableSlotModel.generateSlotKeys(draft.startTime);

    return await _firestore.runTransaction<String>((transaction) async {
      final slotRefs = slotKeys.map((key) {
        return _firestore
            .collection('tables')
            .doc(draft.tableId)
            .collection('slots')
            .doc(key);
      }).toList();

      // Kiểm tra xem có bất kỳ slot nào đã bị chiếm dụng chưa
      for (final ref in slotRefs) {
        final snapshot = await transaction.get(ref);
        if (snapshot.exists) {
          throw Exception(
            'Bàn "${draft.tableName}" đã có người đặt trong khung giờ này. '
            'Vui lòng chọn thời gian khác hoặc bàn khác.',
          );
        }
      }

      final resDocRef = _firestore.collection('reservations').doc();
      final resId = resDocRef.id;

      // Khóa 5 ô slots trong transaction
      for (var i = 0; i < slotRefs.length; i++) {
        transaction.set(slotRefs[i], {
          'reservationId': resId,
          'resStart': Timestamp.fromDate(slotTimes[i]),
        });
      }

      // Lưu tài liệu đặt bàn
      final reservation = draft.copyWith(
        id: resId,
        createdAt: ClockService.instance.serverNow,
      );
      transaction.set(resDocRef, reservation.toMap());

      return resId;
    });
  }

  /// Hủy đơn đặt bàn và giải phóng 5 slot đã khóa.
  Future<void> cancelReservation(String reservationId) async {
    await _firestore.runTransaction((transaction) async {
      final resRef = _firestore.collection('reservations').doc(reservationId);
      final resSnapshot = await transaction.get(resRef);

      if (!resSnapshot.exists || resSnapshot.data() == null) {
        throw Exception('Không tìm thấy đơn đặt bàn cần hủy.');
      }

      final res = ReservationModel.fromMap(resSnapshot.data()!, resSnapshot.id);
      final slotKeys = TableSlotModel.generateSlotKeys(res.startTime);

      // Xóa 5 ô slots liên quan
      for (final key in slotKeys) {
        final slotRef = _firestore
            .collection('tables')
            .doc(res.tableId)
            .collection('slots')
            .doc(key);
        transaction.delete(slotRef);
      }

      // Cập nhật trạng thái đơn đặt thành cancelled
      transaction.update(resRef, {'status': 'cancelled'});
    });
  }

  /// Quét các đơn đặt bàn trạng thái `confirmed` đã quá hạn giữ chỗ (`holdUntil`).
  /// Tự động chuyển sang `no_show` và giải phóng các slot đã giữ.
  /// Trả về số lượng đơn đặt bàn đã quét và giải phóng.
  Future<int> sweepNoShows() async {
    final now = ClockService.instance.serverNow;
    final query = await _firestore
        .collection('reservations')
        .where('status', isEqualTo: 'confirmed')
        .where('holdUntil', isLessThan: Timestamp.fromDate(now))
        .get();

    int count = 0;
    for (final doc in query.docs) {
      final res = ReservationModel.fromMap(doc.data(), doc.id);
      final slotKeys = TableSlotModel.generateSlotKeys(res.startTime);

      final batch = _firestore.batch();
      for (final key in slotKeys) {
        final slotRef = _firestore
            .collection('tables')
            .doc(res.tableId)
            .collection('slots')
            .doc(key);
        batch.delete(slotRef);
      }
      batch.update(doc.reference, {'status': 'no_show'});
      await batch.commit();
      count++;
    }

    return count;
  }

  /// Lắng nghe danh sách đặt bàn của một khách hàng cụ thể theo thời gian thực.
  Stream<List<ReservationModel>> watchCustomerReservations(String customerId) {
    return _firestore
        .collection('reservations')
        .where('customerId', isEqualTo: customerId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReservationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Lắng nghe các đơn đặt bàn có trạng thái `confirmed` trong ngày hôm nay.
  Stream<List<ReservationModel>> watchTodayConfirmedReservations() {
    final now = ClockService.instance.serverNow;
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('reservations')
        .where('status', isEqualTo: 'confirmed')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReservationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Lắng nghe các đơn đặt bàn bị hủy do no-show trong ngày hôm nay.
  Stream<List<ReservationModel>> watchTodayNoShows() {
    final now = ClockService.instance.serverNow;
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('reservations')
        .where('status', isEqualTo: 'no_show')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReservationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
