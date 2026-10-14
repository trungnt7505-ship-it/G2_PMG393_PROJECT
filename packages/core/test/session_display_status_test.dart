import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử SessionService.computeDisplayStatus cho đầy đủ 6 trạng thái', () {
    final sessionService = SessionService();
    final now = DateTime(2026, 10, 14, 10, 0, 0);

    const baseTable = TableModel(
      id: 'table_01',
      name: 'Bàn 01',
      zone: 'Tầng 1',
      capacity: 4,
      status: 'available',
      qrSecret: 'secret_01',
    );

    test('1. Trạng thái cleaning: Khi trạng thái vật lý của bàn là needs_cleaning', () {
      final cleaningTable = baseTable.copyWith(status: 'needs_cleaning');
      final status = sessionService.computeDisplayStatus(cleaningTable, null, null, now);
      expect(status, equals(TableDisplayStatus.cleaning));
    });

    test('2. Trạng thái free: Khi bàn available và không có phiên cũng như lịch hẹn tới', () {
      final status = sessionService.computeDisplayStatus(baseTable, null, null, now);
      expect(status, equals(TableDisplayStatus.free));
    });

    test('3. Trạng thái reservedSoon: Khi bàn available và có khách đặt hẹn tới trong vòng 30 phút', () {
      final nextRes = ReservationModel(
        id: 'res_01',
        customerId: 'cust_01',
        customerName: 'Nguyễn Văn A',
        phone: '0901234567',
        tableId: 'table_01',
        tableName: 'Bàn 01',
        partySize: 4,
        startTime: now.add(const Duration(minutes: 20)), // 20 phút nữa tới (< 30 phút)
        endTime: now.add(const Duration(minutes: 140)),
        holdUntil: now.add(const Duration(minutes: 35)),
        status: 'confirmed',
        createdAt: now.subtract(const Duration(hours: 1)),
      );

      final status = sessionService.computeDisplayStatus(baseTable, null, nextRes, now);
      expect(status, equals(TableDisplayStatus.reservedSoon));
    });

    test('4. Trạng thái using: Khi bàn đang có phiên hoạt động và còn nhiều hơn 15 phút', () {
      final activeSession = SessionModel(
        id: 'session_01',
        tableId: 'table_01',
        tableName: 'Bàn 01',
        openedBy: 'waiter_01',
        openedByRole: 'waiter',
        startedAt: now.subtract(const Duration(minutes: 30)),
        expiresAt: now.add(const Duration(minutes: 90)), // Còn 90 phút (> 15 phút)
        status: 'active',
      );

      final status = sessionService.computeDisplayStatus(baseTable, activeSession, null, now);
      expect(status, equals(TableDisplayStatus.using));
    });

    test('5. Trạng thái expiring: Khi bàn đang có phiên hoạt động nhưng thời gian còn lại <= 15 phút', () {
      final expiringSession = SessionModel(
        id: 'session_01',
        tableId: 'table_01',
        tableName: 'Bàn 01',
        openedBy: 'waiter_01',
        openedByRole: 'waiter',
        startedAt: now.subtract(const Duration(minutes: 108)),
        expiresAt: now.add(const Duration(minutes: 12)), // Còn 12 phút (<= 15 phút)
        status: 'active',
      );

      final status = sessionService.computeDisplayStatus(baseTable, expiringSession, null, now);
      expect(status, equals(TableDisplayStatus.expiring));
    });

    test('6. Trạng thái overtime: Khi bàn đang có phiên hoạt động nhưng đã quá giờ hết hạn', () {
      final overtimeSession = SessionModel(
        id: 'session_01',
        tableId: 'table_01',
        tableName: 'Bàn 01',
        openedBy: 'waiter_01',
        openedByRole: 'waiter',
        startedAt: now.subtract(const Duration(minutes: 130)),
        expiresAt: now.subtract(const Duration(minutes: 10)), // Đã quá giờ 10 phút
        status: 'active',
      );

      final status = sessionService.computeDisplayStatus(baseTable, overtimeSession, null, now);
      expect(status, equals(TableDisplayStatus.overtime));
    });
  });
}

