import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SessionModel session({String status = 'active', int subtotal = 0}) => SessionModel(
    id: 's', tableId: 'target', tableName: 'Demo', customerName: 'Khách',
    openedBy: 'waiter', openedByRole: 'waiter', startedAt: DateTime(2026),
    expiresAt: DateTime(2027), status: status, subtotal: subtotal, reservationId: 'res');

  test('Cancel after switching tables releases only slots of the linked reservation', () async {
    final db = FakeFirebaseFirestore();
    final start = DateTime(2026, 10, 29, 12);
    await db.doc('sessions/s').set(session().toMap());
    await db.doc('tables/target').set({'status': 'occupied', 'currentSessionId': 's'});
    await db.doc('reservations/res').set(ReservationModel(
      id: 'res', customerId: 'c', customerName: 'Khách', phone: '',
      tableId: 'original', tableName: 'Bàn cũ', partySize: 2, startTime: start,
      endTime: start.add(const Duration(hours: 2)), holdUntil: start,
      createdAt: start, status: 'checked_in', sessionId: 's',
    ).toMap());
    final keys = TableSlotModel.generateSlotKeys(start);
    for (var i = 0; i < keys.length; i++) {
      await db.doc('tables/original/slots/${keys[i]}').set({'reservationId': i == 1 ? 'another' : 'res'});
    }
    await SessionService(firestore: db).cancelMistakenSession('s');
    await Future<void>.delayed(Duration.zero);
    expect((await db.doc('sessions/s').get()).data()!['status'], 'cancelled');
    expect((await db.doc('reservations/res').get()).data()!['status'], 'cancelled');
    expect((await db.doc('tables/target').get()).data()!['status'], 'available');
    final slots = (await db.collection('tables/original/slots').get()).docs;
    expect(slots.length, 1);
    expect(slots.single.data()['reservationId'], 'another');
  });
  for (final scenario in ['paid', 'pending', 'different_session']) {
    test('Cancel refuses $scenario without freeing the table', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('sessions/s').set(session(status: scenario == 'paid' ? 'paid' : 'active').toMap());
      final owner = scenario == 'different_session' ? 'new_session' : 's';
      await db.doc('tables/target').set({'status': 'occupied', 'currentSessionId': owner});
      if (scenario == 'pending') {
        await db.doc('sessions/s/orders/order').set({'status': 'pending'});
      }
      await expectLater(SessionService(firestore: db).cancelMistakenSession('s'), throwsA(isA<StateError>()));
      expect((await db.doc('tables/target').get()).data()!['status'], 'occupied');
      expect((await db.doc('tables/target').get()).data()!['currentSessionId'], owner);
    });
  }
}
