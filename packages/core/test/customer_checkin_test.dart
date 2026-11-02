import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Customer QR claims only own eligible booking and creates pending preorder', () async {
    final db = FakeFirebaseFirestore();
    final now = DateTime.now();
    await db.doc('config/app').set(AppConfig.defaultConfig.toMap());
    await db.doc('users/customer').set({'displayName': 'Customer', 'role': 'customer', 'points': 0});
    await db.doc('tables/table').set(const TableModel(id: 'table', name: 'Bàn', zone: 'Tầng 1', capacity: 4, qrSecret: 'secret').toMap());
    await db.doc('reservations/booking').set(ReservationModel(id: 'booking', customerId: 'customer', customerName: 'Customer', phone: '', tableId: 'table', tableName: 'Bàn', partySize: 2, startTime: now, endTime: now.add(const Duration(hours: 2)), holdUntil: now.add(const Duration(minutes: 15)), createdAt: now, preOrderItems: const [OrderItemModel(itemId: 'coffee', name: 'Coffee', unitPrice: 20000, qty: 1)]).toMap());
    final service = SessionService(firestore: db);
    await expectLater(service.checkInByTableQr(qrContent: 'cafe://table/table?k=bad', customerId: 'customer'), throwsException);
    await expectLater(service.checkInByTableQr(qrContent: 'cafe://table/table?k=secret', customerId: 'other'), throwsStateError);
    final id = await service.checkInByTableQr(qrContent: 'cafe://table/table?k=secret', customerId: 'customer');
    await Future<void>.delayed(Duration.zero);
    expect((await db.doc('tables/table').get()).data()!['currentSessionId'], id);
    expect((await db.doc('sessions/$id').get()).data()!['customerId'], 'customer');
    expect((await db.collection('sessions/$id/orders').get()).docs.single.data()['status'], 'pending');
    await expectLater(service.checkInByTableQr(qrContent: 'cafe://table/table?k=secret', customerId: 'customer'), throwsStateError);
  });
}
