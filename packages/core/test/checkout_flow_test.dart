import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PaymentService payments;
  late OrderService orders;
  final now = DateTime(2026, 10, 18, 10);
  const item = OrderItemModel(
      itemId: 'coffee', name: 'Cà phê', unitPrice: 100000, qty: 1);

  Future<void> seed({String status = 'served', bool takeaway = false}) async {
    await db.doc('config/app').set(AppConfig.defaultConfig.toMap());
    await db.doc('users/customer').set(UserModel(
            id: 'customer',
            role: 'customer',
            displayName: 'Khách',
            phone: '090',
            email: 'customer@example.com',
            points: 100,
            createdAt: now)
        .toMap());
    await db
        .doc('tables/table')
        .set({'status': 'occupied', 'currentSessionId': 'session'});
    await db.doc('sessions/session').set(SessionModel(
            id: 'session',
            tableId: 'table',
            tableName: 'Bàn 01',
            customerName: 'Khách',
            openedBy: 'cashier',
            openedByRole: 'counter',
            startedAt: now,
            expiresAt: now.add(const Duration(hours: 2)),
            subtotal: 100000,
            customerId: 'customer')
        .toMap());
    final sid = takeaway ? 'takeaway_orders' : 'session';
    await db.doc('sessions/$sid/orders/order').set(OrderModel(
            id: 'order',
            sessionId: sid,
            tableId: takeaway ? 'takeaway' : 'table',
            tableName: takeaway ? 'Mang đi' : 'Bàn 01',
            type: takeaway ? 'takeaway' : 'dine_in',
            items: const [item],
            createdBy: 'cashier',
            createdByRole: 'counter',
            status: status,
            total: 100000,
            createdAt: now,
            updatedAt: now)
        .toMap());
  }

  Future<PaymentModel> close({int points = 0}) => payments.payAndClose(
      sessionId: 'session',
      cashierId: 'cashier',
      method: PaymentMethod.cash,
      pointsUsed: points);

  setUp(() {
    db = FakeFirebaseFirestore();
    payments = PaymentService(firestore: db);
    orders = OrderService(firestore: db);
  });

  test('Checkout closes table, excludes cancelled items and awards points once',
      () async {
    await seed();
    await db.doc('sessions/session/orders/cancelled').set(OrderModel(
            id: 'cancelled',
            sessionId: 'session',
            tableId: 'table',
            tableName: 'Bàn 01',
            items: const [item],
            createdBy: 'cashier',
            createdByRole: 'counter',
            status: 'cancelled',
            total: 100000,
            createdAt: now,
            updatedAt: now)
        .toMap());
    await db.doc('sessions/session').update({'subtotal': 200000});
    final payment = await close(points: 80);
    expect(payment.subtotal, 100000);
    expect(payment.pointsUsed, 50);
    expect(payment.total, 50000);
    expect((await db.doc('users/customer').get()).data()!['points'], 55);
    expect((await db.doc('sessions/session').get()).data()!['status'], 'paid');
    expect((await db.doc('tables/table').get()).data()!['status'],
        'needs_cleaning');
    expect((await db.doc('tables/table').get()).data()!['currentSessionId'],
        isNull);
    expect(await payments.getPaymentItems(payment.id), hasLength(1));
    await expectLater(close(), throwsStateError);
    expect((await db.collection('payments').get()).docs, hasLength(1));
    expect((await db.doc('users/customer').get()).data()!['points'], 55);
  });

  test('Pending orders prevent checkout without partial writes', () async {
    await seed(status: 'pending');
    await expectLater(close(), throwsStateError);
    expect((await db.collection('payments').get()).docs, isEmpty);
    expect(
        (await db.doc('sessions/session').get()).data()!['status'], 'active');
  });

  test('Changed configuration controls checkout points and discount', () async {
    await seed();
    await db.doc('config/app').update({
      'maxRedeemPercent': 20,
      'pointRedeemVnd': 2000,
      'pointEarnVnd': 20000
    });
    final payment = await close(points: 80);
    expect(payment.pointsUsed, 10);
    expect(payment.discount, 20000);
    expect(payment.total, 80000);
    expect(payment.pointsEarned, 4);
  });

  test('Checkout completes reservation and releases its slots only', () async {
    await seed();
    await db.doc('sessions/session').update({'reservationId': 'reservation'});
    await db.doc('reservations/reservation').set({
      'status': 'checked_in',
      'preOrderItems': [item.toMap()]
    });
    await db
        .doc('tables/table/slots/one')
        .set({'reservationId': 'reservation'});
    await db.doc('tables/table/slots/other').set({'reservationId': 'other'});
    final payment = await close();
    expect(payment.bonusPoints, 10);
    expect((await db.doc('reservations/reservation').get()).data()!['status'],
        'completed');
    expect((await db.doc('tables/table/slots/one').get()).exists, isFalse);
    expect((await db.doc('tables/table/slots/other').get()).exists, isTrue);
  });

  test('Booking without preorder does not earn preorder bonus', () async {
    await seed();
    await db.doc('sessions/session').update({'reservationId': 'reservation'});
    await db
        .doc('reservations/reservation')
        .set({'status': 'checked_in', 'preOrderItems': []});
    expect((await close()).bonusPoints, 0);
  });

  test('Insufficient member points or stale table prevents checkout', () async {
    await seed();
    await db.doc('users/customer').update({'points': 1});
    await expectLater(close(points: 50), throwsStateError);
    await db
        .doc('tables/table')
        .update({'currentSessionId': 'another_session'});
    await expectLater(close(), throwsStateError);
    expect((await db.collection('payments').get()).docs, isEmpty);
  });

  test('Takeaway payment records revenue once without closing a table',
      () async {
    await seed(takeaway: true, status: 'ready');
    final payment = await payments.payTakeaway(
        orderId: 'order',
        cashierId: 'cashier',
        method: PaymentMethod.qr,
        customerId: 'customer',
        pointsUsed: 20);
    expect(payment.total, 80000);
    expect(payment.bonusPoints, 0);
    expect(
        (await db.doc('sessions/takeaway_orders/orders/order').get())
            .data()!['status'],
        'ready');
    expect(
        (await db.doc('sessions/takeaway_orders/orders/order').get())
            .data()!['paymentId'],
        payment.id);
    expect((await db.doc('tables/table').get()).data()!['status'], 'occupied');
    expect(
        (await db.doc('sessions/session').get()).data()!['status'], 'active');
    expect((await payments.watchTodayPayments().first).map((p) => p.id),
        contains(payment.id));
    await expectLater(
        payments.payTakeaway(
            orderId: 'order', cashierId: 'cashier', method: PaymentMethod.cash),
        throwsStateError);
    expect((await db.collection('payments').get()).docs, hasLength(1));
    await expectLater(
        orders.cancelOrder('takeaway_orders', 'order', reason: 'test'),
        throwsStateError);
  });

  test('Takeaway cannot be paid before preparation completes', () async {
    await seed(takeaway: true, status: 'preparing');
    await expectLater(
        payments.payTakeaway(
            orderId: 'order', cashierId: 'cashier', method: PaymentMethod.cash),
        throwsStateError);
  });

  test(
      'Order create, approve and cancel preserve totals and reject a closed session',
      () async {
    await seed(status: 'pending');
    await orders.approveOrder('session', 'order');
    expect(
        (await db.doc('sessions/session').get()).data()!['subtotal'], 200000);
    await orders.cancelOrder('session', 'order', reason: 'Đổi ý');
    expect(
        (await db.doc('sessions/session').get()).data()!['subtotal'], 100000);
    await db
        .doc('menuItems/coffee')
        .set({'name': 'Cà phê', 'price': 100000, 'available': true});
    await db.doc('sessions/session').update({'status': 'paid'});
    await expectLater(
        orders.submitOrder(
            sessionId: 'session',
            tableId: 'table',
            tableName: 'Bàn 01',
            items: const [item],
            createdBy: 'customer',
            createdByRole: 'customer'),
        throwsStateError);
  });

  test(
      'Config save validates, preserves unknown fields and detects concurrent edits',
      () async {
    await seed();
    await db.doc('config/app').update({'extension': 'keep'});
    final service = ConfigService(firestore: db);
    await service.save(AppConfig.defaultConfig.copyWith(sessionMinutes: 90),
        expected: AppConfig.defaultConfig);
    expect((await db.doc('config/app').get()).data()!['extension'], 'keep');
    await expectLater(
        service.save(AppConfig.defaultConfig.copyWith(sessionMinutes: 60),
            expected: AppConfig.defaultConfig),
        throwsStateError);
    await expectLater(
        service.save(AppConfig.defaultConfig.copyWith(pointRedeemVnd: 0)),
        throwsFormatException);
  });

  test('Session statistics exclude past days and do not lose paid sessions',
      () async {
    final today = ClockService.instance.serverNow;
    final start = DateTime(today.year, today.month, today.day);
    for (final entry in {
      'today': start,
      'yesterday': start.subtract(const Duration(days: 1)),
      'tomorrow': start.add(const Duration(days: 1))
    }.entries) {
      await db
          .doc('sessions/${entry.key}')
          .set({'startedAt': entry.value, 'status': 'paid'});
    }
    final sessions =
        await SessionService(firestore: db).watchTodaySessions().first;
    expect(sessions.map((s) => s.id), ['today']);
  });

  test(
      'Point conversion never discounts a fractional point or accepts negatives',
      () {
    final calc =
        PaymentService.calculatePayment(subtotal: 33333, pointsUsed: 100);
    expect(calc.pointsUsed, 16);
    expect(calc.discount, 16000);
    expect(() => PaymentService.calculatePayment(subtotal: 100, pointsUsed: -1),
        throwsArgumentError);
  });

  test('A stale amount or configuration requires confirmation again', () async {
    await seed();
    await expectLater(
        payments.payAndClose(
            sessionId: 'session',
            cashierId: 'cashier',
            method: PaymentMethod.cash,
            expectedSubtotal: 90000),
        throwsStateError);
    await db.doc('config/app').update({'maxRedeemPercent': 20});
    await expectLater(
        payments.payAndClose(
            sessionId: 'session',
            cashierId: 'cashier',
            method: PaymentMethod.cash,
            expectedSubtotal: 100000,
            expectedConfig: AppConfig.defaultConfig),
        throwsStateError);
    expect((await db.collection('payments').get()).docs, isEmpty);
  });

  test('Pending new orders update session revision and block checkout',
      () async {
    await seed();
    await db
        .doc('menuItems/coffee')
        .set({'name': 'Cà phê', 'price': 100000, 'available': true});
    await orders.submitOrder(
        sessionId: 'session',
        tableId: 'table',
        tableName: 'Bàn',
        items: const [item],
        createdBy: 'customer',
        createdByRole: 'customer');
    expect(
        (await db.doc('sessions/session').get()).data()!['orderRevision'], 1);
    await expectLater(close(), throwsStateError);
  });
}
