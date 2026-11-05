import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Preorder review records receipt without creating duplicate kitchen orders',
      () async {
    final db = FakeFirebaseFirestore();
    await db
        .doc('reservations/r')
        .set({'status': 'confirmed', 'preOrderItems': []});
    final service = CustomerWorkflowService(firestore: db);
    await service.reviewPreorder('r', 'waiter');
    await Future<void>.delayed(Duration.zero);
    await service.reviewPreorder('r', 'waiter');
    await Future<void>.delayed(Duration.zero);
    expect((await db.doc('reservations/r').get()).data()!['preorderReviewedBy'],
        'waiter');
    expect((await db.collectionGroup('orders').get()).docs, isEmpty);
  });
  test(
      'Extension request does not extend until approved and cannot approve twice',
      () async {
    final db = FakeFirebaseFirestore();
    final now = DateTime.now();
    await db.doc('config/app').set(AppConfig.defaultConfig.toMap());
    await db.doc('sessions/s').set(SessionModel(
            id: 's',
            tableId: 't',
            tableName: 'T',
            customerId: 'c',
            customerName: 'C',
            openedBy: 'w',
            openedByRole: 'waiter',
            startedAt: now,
            expiresAt: now.add(const Duration(hours: 2)))
        .toMap());
    final service = SessionService(firestore: db);
    final before = (await db.doc('sessions/s').get()).data()!['expiresAt'];
    await service.requestExtension('s', 'c');
    await Future<void>.delayed(Duration.zero);
    expect((await db.doc('sessions/s').get()).data()!['expiresAt'], before);
    final req = (await db.collection('requests').get()).docs.single;
    await expectLater(service.requestExtension('s', 'c'), throwsStateError);
    expect(
        await service.extendSession('s', byUid: 'w', approvalRequestId: req.id),
        30);
    await Future<void>.delayed(Duration.zero);
    expect((await db.doc(req.reference.path).get()).data()!['decision'],
        'approved');
    await expectLater(
        service.extendSession('s', byUid: 'w', approvalRequestId: req.id),
        throwsStateError);
  });
  test('Reject extension preserves session expiry', () async {
    final db = FakeFirebaseFirestore();
    final now = DateTime.now();
    await db.doc('sessions/s').set(SessionModel(
            id: 's',
            tableId: 't',
            tableName: 'T',
            customerId: 'c',
            customerName: 'C',
            openedBy: 'w',
            openedByRole: 'waiter',
            startedAt: now,
            expiresAt: now.add(const Duration(hours: 2)))
        .toMap());
    final service = SessionService(firestore: db);
    await service.requestExtension('s', 'c');
    await Future<void>.delayed(Duration.zero);
    final id = (await db.collection('requests').get()).docs.single.id;
    await service.rejectExtension(id, 'w');
    await Future<void>.delayed(Duration.zero);
    expect((await db.doc('sessions/s').get()).data()!['extendedMinutes'], 0);
    expect(
        (await db.doc('requests/$id').get()).data()!['decision'], 'rejected');
  });
  test('Online takeaway is idempotent and keeps recipient snapshot', () async {
    final db = FakeFirebaseFirestore();
    await db
        .doc('menuItems/m')
        .set({'name': 'Coffee', 'price': 20000, 'available': true});
    final service = OrderService(firestore: db);
    Future<String> submit() => service.submitOrder(
        sessionId: 'takeaway_orders',
        tableId: 'takeaway',
        tableName: 'Mang đi',
        items: const [
          OrderItemModel(itemId: 'm', name: 'Coffee', unitPrice: 1, qty: 2)
        ],
        createdBy: 'c',
        createdByRole: 'customer',
        type: OrderType.takeaway,
        recipientName: 'Customer',
        recipientPhone: '0900000000',
        clientOrderId: 'stable');
    expect(await submit(), 'stable');
    await Future<void>.delayed(Duration.zero);
    expect(await submit(), 'stable');
    final rows =
        (await db.collection('sessions/takeaway_orders/orders').get()).docs;
    expect(rows, hasLength(1));
    expect(rows.single.data()['total'], 40000);
    expect(rows.single.data()['recipientPhone'], '0900000000');
    expect(rows.single.data()['status'], 'pending');
  });
}
