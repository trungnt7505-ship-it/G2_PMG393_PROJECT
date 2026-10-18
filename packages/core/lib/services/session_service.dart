import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_config.dart';
import '../constants/enums.dart';
import '../models/order_model.dart';
import '../models/request_model.dart';
import '../models/reservation_model.dart';
import '../models/session_model.dart';
import '../models/table_model.dart';
import 'clock_service.dart';
import 'config_service.dart';

/// Dịch vụ quản lý vòng đời của phiên dùng bàn (Session), chuyển bàn, gia hạn
/// và đồng bộ trạng thái hiển thị của sơ đồ bàn.
class SessionService {
  /// Phiên bắt đầu trong ngày theo đồng hồ server, gồm cả phiên đã thanh toán.
  Stream<List<SessionModel>> watchTodaySessions() {
    final now = ClockService.instance.serverNow;
    final start = DateTime(now.year, now.month, now.day);
    return _firestore
        .collection('sessions')
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startedAt',
            isLessThan: Timestamp.fromDate(start.add(const Duration(days: 1))))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.id != 'takeaway_orders')
            .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  SessionService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  /// Tính toán trạng thái hiển thị giao diện của bàn theo thời gian thực (Client-computed).
  ///
  /// Quy tắc tính:
  /// 1. Nếu trạng thái bàn là `needs_cleaning` -> [TableDisplayStatus.cleaning]
  /// 2. Nếu có phiên hoạt động (`active` hoặc `billing`):
  ///    - Nếu `now > expiresAt` -> [TableDisplayStatus.overtime]
  ///    - Nếu thời gian còn lại `<= 15 phút` -> [TableDisplayStatus.expiring]
  ///    - Ngược lại -> [TableDisplayStatus.using]
  /// 3. Nếu không có phiên hoạt động:
  ///    - Nếu có đơn đặt hẹn tiếp theo [nextRes] trong vòng 30 phút tới và chưa quá hạn giữ chỗ -> [TableDisplayStatus.reservedSoon]
  ///    - Ngược lại -> [TableDisplayStatus.free]
  TableDisplayStatus computeDisplayStatus(
    TableModel table,
    SessionModel? activeSession,
    ReservationModel? nextRes,
    DateTime now, {
    AppConfig config = AppConfig.defaultConfig,
  }) {
    if (table.physicalStatus == TablePhysicalStatus.needs_cleaning) {
      return TableDisplayStatus.cleaning;
    }

    if (activeSession != null && activeSession.isActive) {
      if (now.isAfter(activeSession.expiresAt)) {
        return TableDisplayStatus.overtime;
      }
      final remainingMinutes =
          activeSession.expiresAt.difference(now).inMinutes;
      if (remainingMinutes <= config.warnMinutes.reduce(max)) {
        return TableDisplayStatus.expiring;
      }
      return TableDisplayStatus.using;
    }

    if (nextRes != null &&
        nextRes.reservationStatus == ReservationStatus.confirmed) {
      final isBeforeHoldUntil = now.isBefore(nextRes.holdUntil);
      final differenceMinutes = nextRes.startTime.difference(now).inMinutes;
      // Khách sắp đến trong vòng 30 phút tới và chưa bị quá giờ giữ chỗ
      if (isBeforeHoldUntil &&
          differenceMinutes <= 30 &&
          differenceMinutes >= -15) {
        return TableDisplayStatus.reservedSoon;
      }
    }

    return TableDisplayStatus.free;
  }

  /// Mở phiên sử dụng bàn mới.
  ///
  /// Thực hiện trong Firestore Transaction:
  /// 1. Kiểm tra bàn có đang `available` hay không.
  /// 2. Kiểm tra các slot đặt trước tiếp theo để cắt ngắn thời lượng phiên nếu vướng lịch sau.
  /// 3. Tạo tài liệu `sessions/{sessionId}`.
  /// 4. Đổi trạng thái bàn sang `occupied` và gán `currentSessionId`.
  /// 5. Nếu mở từ đặt chỗ [reservationId]:
  ///    - Chuyển trạng thái reservation sang `checked_in`.
  ///    - Tự động tạo đơn hàng đầu tiên từ danh sách món đặt trước `preOrderItems`.
  ///    - Đơn có trạng thái `confirmed` nếu nhân viên mở hộ, hoặc `pending` nếu khách tự mở.
  Future<String> openSession({
    required String tableId,
    String? customerId,
    String customerName = 'Khách vãng lai',
    required String openedBy,
    required String openedByRole,
    String? reservationId,
  }) async {
    final now = ClockService.instance.serverNow;

    return await _firestore.runTransaction<String>((transaction) async {
      final config = await ConfigService(firestore: _firestore)
          .read(transaction: transaction);
      final tableRef = _firestore.collection('tables').doc(tableId);
      final tableSnapshot = await transaction.get(tableRef);

      if (!tableSnapshot.exists || tableSnapshot.data() == null) {
        throw Exception('Không tìm thấy thông tin bàn $tableId.');
      }

      final table = TableModel.fromMap(tableSnapshot.data()!, tableSnapshot.id);
      if (table.physicalStatus != TablePhysicalStatus.available) {
        throw Exception(
          'Bàn "${table.name}" hiện không thể mở phiên (Trạng thái: ${table.status}).',
        );
      }

      int baseMinutes = config.sessionMinutes; // 120 phút mặc định

      // Kiểm tra slot đặt trước tiếp theo của bàn để cắt thời gian nếu cần
      final slotsQuery = await _firestore
          .collection('tables')
          .doc(tableId)
          .collection('slots')
          .where('resStart', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('resStart')
          .limit(1)
          .get();

      if (slotsQuery.docs.isNotEmpty) {
        final nextSlot = slotsQuery.docs.first.data();
        final nextSlotResId = nextSlot['reservationId'] as String?;
        // Nếu slot kế tiếp không thuộc về chính đơn đặt chỗ hiện tại đang check-in
        if (nextSlotResId != null && nextSlotResId != reservationId) {
          final nextSlotStart = (nextSlot['resStart'] as Timestamp).toDate();
          final minutesUntilNext = nextSlotStart.difference(now).inMinutes;
          final availableMinutes = minutesUntilNext - config.bufferMinutes;

          if (availableMinutes < 10) {
            throw StateError(
                'Không đủ thời gian mở bàn trước lượt đặt tiếp theo.');
          }
          baseMinutes = min(baseMinutes, availableMinutes);
        }
      }

      final expiresAt = now.add(Duration(minutes: baseMinutes));
      final sessionRef = _firestore.collection('sessions').doc();
      final sessionId = sessionRef.id;

      ReservationModel? reservation;
      if (reservationId != null) {
        final resRef = _firestore.collection('reservations').doc(reservationId);
        final resSnapshot = await transaction.get(resRef);
        if (resSnapshot.exists && resSnapshot.data() != null) {
          reservation =
              ReservationModel.fromMap(resSnapshot.data()!, resSnapshot.id);
          if (reservation.reservationStatus != ReservationStatus.confirmed ||
              reservation.tableId != tableId ||
              now.isBefore(reservation.startTime
                  .subtract(Duration(minutes: config.checkInEarlyMinutes))) ||
              now.isAfter(reservation.holdUntil)) {
            throw StateError(
                'Đặt bàn không hợp lệ hoặc chưa đến/đã quá thời gian nhận bàn.');
          }
          transaction.update(resRef, {
            'status': ReservationStatus.checked_in.name,
            'sessionId': sessionId,
          });
        } else {
          throw StateError('Không tìm thấy đặt bàn để nhận bàn.');
        }
      }

      int initialSubtotal = 0;

      // Nếu có món đặt trước, tạo đơn gọi món đầu tiên
      if (reservation != null && reservation.hasPreOrder) {
        final orderRef = sessionRef.collection('orders').doc();
        final isStaff = openedByRole != 'customer';
        final orderStatus =
            isStaff ? OrderStatus.confirmed.name : OrderStatus.pending.name;
        final total = reservation.preOrderTotal;

        final firstOrder = OrderModel(
          id: orderRef.id,
          sessionId: sessionId,
          tableId: table.id,
          tableName: table.name,
          items: reservation.preOrderItems,
          createdBy: openedBy,
          createdByRole: openedByRole,
          type: OrderType.dine_in.name,
          status: orderStatus,
          total: total,
          createdAt: now,
          updatedAt: now,
        );

        transaction.set(orderRef, firstOrder.toMap());
        if (isStaff) {
          initialSubtotal = total;
        }
      }

      // Tạo Session
      final session = SessionModel(
        id: sessionId,
        tableId: table.id,
        tableName: table.name,
        customerId: customerId ?? reservation?.customerId,
        customerName: customerId != null
            ? customerName
            : (reservation?.customerName ?? customerName),
        guestPhone: reservation?.phone,
        openedBy: openedBy,
        openedByRole: openedByRole,
        reservationId: reservationId,
        startedAt: now,
        baseMinutes: baseMinutes,
        extendedMinutes: 0,
        expiresAt: expiresAt,
        extensions: const [],
        earlyReleased: false,
        status: SessionStatus.active.name,
        subtotal: initialSubtotal,
      );

      transaction.set(sessionRef, session.toMap());

      // Cập nhật trạng thái bàn
      transaction.update(tableRef, {
        'status': TablePhysicalStatus.occupied.name,
        'currentSessionId': sessionId,
      });

      return sessionId;
    });
  }

  /// Khách hàng quét mã QR dán tại bàn để tự check-in nhận bàn hoặc tự mở bàn mới.
  /// Định dạng QR: `cafe://table/{tableId}?k={qrSecret}`.
  Future<String> checkInByTableQr({
    required String qrContent,
    required String customerId,
    String? reservationId,
  }) async {
    final uri = Uri.tryParse(qrContent.trim());
    if (uri == null || uri.scheme != 'cafe' || uri.host != 'table') {
      throw Exception('Mã QR không đúng định dạng bàn của quán Cafe.');
    }

    final tableId =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first : uri.path;
    final secretKey = uri.queryParameters['k'];

    if (tableId.isEmpty || secretKey == null) {
      throw Exception('Mã QR thiếu thông tin bàn hoặc mã xác thực.');
    }

    final tableDoc = await _firestore.collection('tables').doc(tableId).get();
    if (!tableDoc.exists || tableDoc.data() == null) {
      throw Exception('Không tìm thấy bàn trên hệ thống.');
    }

    final table = TableModel.fromMap(tableDoc.data()!, tableDoc.id);
    if (table.qrSecret != secretKey) {
      throw Exception('Mã xác thực bàn không chính xác hoặc đã bị đổi.');
    }

    // Lấy tên khách hàng
    final userDoc = await _firestore.collection('users').doc(customerId).get();
    final customerName =
        userDoc.data()?['displayName'] as String? ?? 'Khách hàng';

    return await openSession(
      tableId: tableId,
      customerId: customerId,
      customerName: customerName,
      openedBy: customerId,
      openedByRole: 'customer',
      reservationId: reservationId,
    );
  }

  /// Thu ngân quét mã QR đơn đặt trước của khách tại quầy để check-in mở bàn ngay.
  /// Định dạng QR: `cafe://preorder/{resId}`.
  Future<String> checkInByPreOrderQrAtCounter({
    required String qrContent,
    required String counterUid,
    String? assignTableId,
  }) async {
    final uri = Uri.tryParse(qrContent.trim());
    if (uri == null || uri.scheme != 'cafe' || uri.host != 'preorder') {
      throw Exception('Mã QR không đúng định dạng đơn đặt trước.');
    }

    final resId =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first : uri.path;
    if (resId.isEmpty) {
      throw Exception('Mã QR không chứa mã đơn đặt trước.');
    }

    final resDoc = await _firestore.collection('reservations').doc(resId).get();
    if (!resDoc.exists || resDoc.data() == null) {
      throw Exception('Không tìm thấy đơn đặt bàn trên hệ thống.');
    }

    final reservation = ReservationModel.fromMap(resDoc.data()!, resDoc.id);
    final targetTableId = assignTableId ?? reservation.tableId;

    return await openSession(
      tableId: targetTableId,
      customerId: reservation.customerId,
      customerName: reservation.customerName,
      openedBy: counterUid,
      openedByRole: 'counter',
      reservationId: resId,
    );
  }

  /// Gia hạn phiên dùng bàn thêm `extendStepMinutes` (mặc định 30 phút),
  /// hoặc tối đa tới trước giờ khách hẹn kế tiếp (trừ đi 15 phút dọn bàn).
  /// Trả về số phút được gia hạn thực tế.
  Future<int> extendSession(
    String sessionId, {
    required String byUid,
  }) async {
    final now = ClockService.instance.serverNow;

    return await _firestore.runTransaction<int>((transaction) async {
      final config = await ConfigService(firestore: _firestore)
          .read(transaction: transaction);
      final sessionRef = _firestore.collection('sessions').doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists || sessionSnapshot.data() == null) {
        throw Exception('Không tìm thấy phiên dùng bàn.');
      }

      final session =
          SessionModel.fromMap(sessionSnapshot.data()!, sessionSnapshot.id);
      if (!session.isActive) {
        throw Exception('Phiên dùng bàn đã kết thúc, không thể gia hạn.');
      }

      int minutesToAdd = config.extendStepMinutes; // 30 phút

      // Kiểm tra slot đặt tiếp theo sau thời điểm hết hạn hiện tại
      final nextSlots = await _firestore
          .collection('tables')
          .doc(session.tableId)
          .collection('slots')
          .where('resStart',
              isGreaterThanOrEqualTo: Timestamp.fromDate(session.expiresAt))
          .orderBy('resStart')
          .limit(1)
          .get();

      if (nextSlots.docs.isNotEmpty) {
        final nextSlot = nextSlots.docs.first.data();
        final nextStart = (nextSlot['resStart'] as Timestamp).toDate();
        final maxExtendMinutes =
            nextStart.difference(session.expiresAt).inMinutes -
                config.bufferMinutes;

        if (maxExtendMinutes < 10) {
          throw Exception(
            'Không thể gia hạn thêm vì bàn đã có khách đặt trước ngay sau đó.',
          );
        }

        minutesToAdd = min(minutesToAdd, maxExtendMinutes);
      }

      final newExpiresAt =
          session.expiresAt.add(Duration(minutes: minutesToAdd));
      final updatedExtensions = List<SessionExtension>.from(session.extensions)
        ..add(SessionExtension(at: now, minutes: minutesToAdd, by: byUid));

      transaction.update(sessionRef, {
        'extendedMinutes': session.extendedMinutes + minutesToAdd,
        'expiresAt': Timestamp.fromDate(newExpiresAt),
        'extensions': updatedExtensions.map((e) => e.toMap()).toList(),
      });

      return minutesToAdd;
    });
  }

  /// Khách hàng yêu cầu trả bàn sớm khi thời gian còn lại >= 30 phút để nhận điểm thưởng.
  /// Chuyển trạng thái phiên sang `billing` và tạo một yêu cầu `early_release`.
  Future<void> requestEarlyRelease(
    String sessionId, {
    required String customerId,
  }) async {
    final now = ClockService.instance.serverNow;
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    return _firestore.runTransaction((transaction) async {
      final config = await ConfigService(firestore: _firestore)
          .read(transaction: transaction);
      final sessionDoc = await transaction.get(sessionRef);

      if (!sessionDoc.exists || sessionDoc.data() == null) {
        throw Exception('Không tìm thấy phiên bàn.');
      }

      final session = SessionModel.fromMap(sessionDoc.data()!, sessionDoc.id);
      if (!session.isActive || session.customerId != customerId) {
        throw StateError('Không thể yêu cầu trả sớm cho phiên này.');
      }
      final remainingMinutes = session.expiresAt.difference(now).inMinutes;

      if (remainingMinutes < config.earlyReleaseMinMinutes) {
        throw Exception(
          'Thời gian còn lại của phiên dưới ${config.earlyReleaseMinMinutes} phút, '
          'không đủ điều kiện nhận điểm thưởng trả bàn sớm.',
        );
      }

      transaction.update(sessionRef, {
        'earlyReleased': true,
        'status': SessionStatus.billing.name,
      });

      // Tạo Request cho nhân viên và quầy
      final reqRef = _firestore.collection('requests').doc();
      final request = RequestModel(
        id: reqRef.id,
        sessionId: sessionId,
        tableId: session.tableId,
        tableName: session.tableName,
        type: RequestType.early_release.name,
        message:
            'Khách yêu cầu trả bàn sớm khi còn $remainingMinutes phút để nhận điểm thưởng.',
        status: 'open',
        createdBy: customerId,
        createdAt: now,
      );

      transaction.set(reqRef, request.toMap());
    });
  }

  /// Chuyển khách sang bàn mới trong trường hợp khách muốn đổi chỗ.
  Future<void> switchTable({
    required String sessionId,
    required String newTableId,
    bool oldTableNeedsCleaning = true,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final sessionRef = _firestore.collection('sessions').doc(sessionId);
      final newTableRef = _firestore.collection('tables').doc(newTableId);

      final sessionSnapshot = await transaction.get(sessionRef);
      final newTableSnapshot = await transaction.get(newTableRef);

      if (!sessionSnapshot.exists || !newTableSnapshot.exists) {
        throw Exception('Thông tin phiên hoặc bàn mới không tồn tại.');
      }

      final session =
          SessionModel.fromMap(sessionSnapshot.data()!, sessionSnapshot.id);
      final newTable =
          TableModel.fromMap(newTableSnapshot.data()!, newTableSnapshot.id);

      if (newTable.physicalStatus != TablePhysicalStatus.available) {
        throw Exception(
            'Bàn mới "${newTable.name}" hiện không còn trống để chuyển sang.');
      }

      final oldTableRef = _firestore.collection('tables').doc(session.tableId);

      // Cập nhật bàn cũ
      transaction.update(oldTableRef, {
        'status': oldTableNeedsCleaning
            ? TablePhysicalStatus.needs_cleaning.name
            : TablePhysicalStatus.available.name,
        'currentSessionId': null,
      });

      // Cập nhật bàn mới
      transaction.update(newTableRef, {
        'status': TablePhysicalStatus.occupied.name,
        'currentSessionId': sessionId,
      });

      // Cập nhật phiên bàn
      transaction.update(sessionRef, {
        'tableId': newTable.id,
        'tableName': newTable.name,
      });
    });
  }

  /// Hủy phiên bàn do nhân viên mở nhầm. Đưa bàn trở lại trạng thái `available`.
  Future<void> cancelMistakenSession(String sessionId) async {
    await _firestore.runTransaction((transaction) async {
      final sessionRef = _firestore.collection('sessions').doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);

      if (!sessionSnapshot.exists || sessionSnapshot.data() == null) {
        throw Exception('Không tìm thấy phiên cần hủy.');
      }

      final session =
          SessionModel.fromMap(sessionSnapshot.data()!, sessionSnapshot.id);
      final tableRef = _firestore.collection('tables').doc(session.tableId);

      transaction.update(sessionRef, {
        'status': SessionStatus.cancelled.name,
      });

      transaction.update(tableRef, {
        'status': TablePhysicalStatus.available.name,
        'currentSessionId': null,
      });
    });
  }

  /// Đánh dấu bàn đã được nhân viên dọn dẹp sạch sẽ, sẵn sàng đón khách tiếp theo.
  Future<void> markTableCleaned(String tableId) async {
    await _firestore.collection('tables').doc(tableId).update({
      'status': TablePhysicalStatus.available.name,
      'currentSessionId': null,
    });
  }

  /// Gửi yêu cầu hỗ trợ từ bàn (Gọi phục vụ, Xin hóa đơn, Nhắc nhả bàn, Trả bàn sớm).
  Future<void> sendTableRequest({
    required String sessionId,
    required String tableId,
    required String tableName,
    required RequestType type,
    required String createdBy,
    String message = '',
  }) async {
    final now = ClockService.instance.serverNow;
    final reqRef = _firestore.collection('requests').doc();

    final request = RequestModel(
      id: reqRef.id,
      sessionId: sessionId,
      tableId: tableId,
      tableName: tableName,
      type: type.name,
      message: message,
      status: 'open',
      createdBy: createdBy,
      createdAt: now,
    );

    await reqRef.set(request.toMap());
  }

  /// Đánh dấu yêu cầu hỗ trợ đã được nhân viên xử lý xong.
  Future<void> resolveRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'done',
    });
  }

  /// Lắng nghe thông tin phiên bàn hiện tại theo thời gian thực.
  Stream<SessionModel?> watchSession(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return SessionModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Lắng nghe danh sách tất cả các phiên đang hoạt động (`active` hoặc `billing`).
  Stream<List<SessionModel>> watchActiveSessions() {
    return _firestore
        .collection('sessions')
        .where('status',
            whereIn: [SessionStatus.active.name, SessionStatus.billing.name])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Lắng nghe danh sách tất cả các bàn trong quán.
  Stream<List<TableModel>> watchAllTables() {
    return _firestore
        .collection('tables')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TableModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Lắng nghe danh sách các yêu cầu đang chờ giải quyết (`status == 'open'`).
  Stream<List<RequestModel>> watchOpenRequests() {
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
