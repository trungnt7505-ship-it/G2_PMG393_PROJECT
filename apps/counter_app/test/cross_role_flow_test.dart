import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kiểm thử hợp đồng service giữa ba vai trò, không thay thế kiểm thử ba UI thật.
void main() {
  test(
      'Customer booking → counter QR → waiter service → checkout → points/statistics',
      () async {
    final db = FakeFirebaseFirestore();
    // FakeFirestore 3.x does not await writes inside its dummy transaction.
    Future<void> flushFakeWrites() => Future<void>.delayed(Duration.zero);
    final sessions = SessionService(firestore: db);
    final orders = OrderService(firestore: db);
    final payments = PaymentService(firestore: db);
    final reservations = ReservationService(firestore: db);
    ClockService.instance.setOffsetForTesting(Duration.zero);
    addTearDown(() => ClockService.instance.setOffsetForTesting(Duration.zero));
    final now = ClockService.instance.serverNow;
    await db.doc('config/app').set(AppConfig.defaultConfig.toMap());
    await db.doc('tables/table').set(const TableModel(
            id: 'table',
            name: 'Bàn 01',
            zone: 'Tầng 1',
            capacity: 4,
            qrSecret: 'secret')
        .toMap());
    await db
        .doc('menuItems/coffee')
        .set({'name': 'Cà phê', 'price': 50000, 'available': true});
    await db.doc('users/customer').set(UserModel(
            id: 'customer',
            role: 'customer',
            displayName: 'Khách',
            phone: '0901000000',
            email: 'customer@example.com',
            points: 100,
            createdAt: now)
        .toMap());
    const item = OrderItemModel(
        itemId: 'coffee', name: 'Cà phê', unitPrice: 50000, qty: 1);
    final start = now.add(const Duration(minutes: 60));
    final reservationId = await reservations.createReservation(ReservationModel(
        id: '',
        customerId: 'customer',
        customerName: 'Khách',
        phone: '0901000000',
        tableId: 'table',
        tableName: 'Bàn 01',
        partySize: 2,
        startTime: start,
        endTime: start.add(const Duration(hours: 2)),
        holdUntil: start.add(const Duration(minutes: 15)),
        createdAt: now,
        preOrderItems: const [item]));
    await flushFakeWrites();
    ClockService.instance.setOffsetForTesting(const Duration(minutes: 50));
    final sid = await sessions.checkInByPreOrderQrAtCounter(
        qrContent: 'cafe://preorder/$reservationId', counterUid: 'counter');
    await flushFakeWrites();
    expect((await db.doc('sessions/$sid').get()).exists, isTrue);
    expect(
        (await sessions
                .watchSession(sid)
                .where((s) => s != null)
                .first
                .timeout(const Duration(seconds: 5)))!
            .subtotal,
        50000);
    final orderId = await orders.submitOrder(
        sessionId: sid,
        tableId: 'table',
        tableName: 'Bàn 01',
        items: const [item],
        createdBy: 'customer',
        createdByRole: 'customer');
    await flushFakeWrites();
    expect(
        (await orders
                .watchAllOrdersByStatuses([OrderStatus.pending])
                .firstWhere((rows) => rows.isNotEmpty)
                .timeout(const Duration(seconds: 5)))
            .single
            .id,
        orderId);
    await orders.approveOrder(sid, orderId);
    await flushFakeWrites();
    await orders.updatePreparationStatus(sid, orderId, OrderStatus.preparing);
    await orders.updatePreparationStatus(sid, orderId, OrderStatus.ready);
    expect(
        (await orders
                .watchAllOrdersByStatuses([OrderStatus.ready])
                .firstWhere((rows) => rows.isNotEmpty)
                .timeout(const Duration(seconds: 5)))
            .single
            .id,
        orderId);
    await orders.updatePreparationStatus(sid, orderId, OrderStatus.served);
    await sessions.sendTableRequest(
        sessionId: sid,
        tableId: 'table',
        tableName: 'Bàn 01',
        type: RequestType.request_bill,
        createdBy: 'customer',
        message: 'Xin tính tiền');
    final request = (await sessions
            .watchOpenRequests()
            .firstWhere((rows) => rows.isNotEmpty)
            .timeout(const Duration(seconds: 5)))
        .single;
    await sessions.resolveRequest(request.id);
    expect(
        await sessions.watchOpenRequests().firstWhere((rows) => rows.isEmpty),
        isEmpty);
    final payment = await payments.payAndClose(
        sessionId: sid,
        cashierId: 'counter',
        method: PaymentMethod.cash,
        customerId: 'customer',
        pointsUsed: 20,
        expectedSubtotal: 100000);
    await flushFakeWrites();
    expect(payment.total, 80000);
    expect(payment.bonusPoints, 10);
    expect(
        (await AuthService(firestore: db).findCustomerById('customer'))!.points,
        98);
    expect(
        (await payments
                .watchTodayPayments()
                .firstWhere((rows) => rows.isNotEmpty)
                .timeout(const Duration(seconds: 5)))
            .single
            .id,
        payment.id);
    expect(
        (await sessions
                .watchTodaySessions()
                .firstWhere((rows) => rows.isNotEmpty)
                .timeout(const Duration(seconds: 5)))
            .single
            .status,
        'paid');
    expect((await db.doc('tables/table').get()).data()!['status'],
        'needs_cleaning');
    expect((await db.collection('tables/table/slots').get()).docs, isEmpty);
    await sessions.markTableCleaned('table');
    expect((await db.doc('tables/table').get()).data()!['status'], 'available');
    await expectLater(
        payments.payAndClose(
            sessionId: sid, cashierId: 'counter', method: PaymentMethod.cash),
        throwsStateError);
    expect((await db.collection('payments').get()).docs, hasLength(1));
  });
}
