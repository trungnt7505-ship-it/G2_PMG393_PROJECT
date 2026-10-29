import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingTransactionStore extends FakeFirebaseFirestore {
  int batches = 0;
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
      {Duration timeout = const Duration(seconds: 30), int maxAttempts = 5}) async {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'aborted');
  }
  @override
  WriteBatch batch() {
    batches++;
    return super.batch();
  }
}

void main() {
  ReservationModel draft() {
    final start = ClockService.instance.serverNow.add(const Duration(hours: 2));
    return ReservationModel(id: '', customerId: 'customer', customerName: 'Demo',
      phone: '', tableId: 'table', tableName: 'Bàn Demo', partySize: 2,
      startTime: start, endTime: start.add(const Duration(hours: 2)),
      holdUntil: start.add(const Duration(minutes: 15)), createdAt: start);
  }
  test('Transaction failure never falls back to unconditional slot batch writes', () async {
    final db = FailingTransactionStore();
    await db.doc('config/app').set(AppConfig.defaultConfig.toMap());
    final service = ReservationService(firestore: db);
    await expectLater(service.createReservation(draft()), throwsA(isA<FirebaseException>()));
    expect(db.batches, 0);
    expect((await db.collection('reservations').get()).docs, isEmpty);
    expect((await db.collection('tables/table/slots').get()).docs, isEmpty);
  });
  test('Occupied slot rejects booking and preserves the original reservation', () async {
    final db = FakeFirebaseFirestore();
    final request = draft();
    final slot = TableSlotModel.generateSlotKeys(request.startTime).first;
    await db.doc('tables/table/slots/$slot').set({'reservationId': 'existing'});
    await expectLater(ReservationService(firestore: db).createReservation(request), throwsException);
    expect((await db.doc('tables/table/slots/$slot').get()).data()!['reservationId'], 'existing');
    expect((await db.collection('reservations').get()).docs, isEmpty);
  });
  test('Extension ignores own reservation slots but respects the next customer', () async {
    final db = FakeFirebaseFirestore();
    final now = ClockService.instance.serverNow;
    await db.doc('config/app').set(AppConfig.defaultConfig.toMap());
    await db.doc('sessions/session').set(SessionModel(
      id: 'session', tableId: 'table', tableName: 'Demo', customerName: 'Khách',
      openedBy: 'counter', openedByRole: 'counter', startedAt: now,
      expiresAt: now.add(const Duration(hours: 2)), reservationId: 'own',
    ).toMap());
    await db.doc('tables/table/slots/own').set({
      'reservationId': 'own', 'resStart': Timestamp.fromDate(now.add(const Duration(minutes: 125))),
    });
    final service = SessionService(firestore: db);
    expect(await service.extendSession('session', byUid: 'customer'), 30);
    await Future<void>.delayed(Duration.zero);
    await db.doc('tables/table/slots/next').set({
      'reservationId': 'next', 'resStart': Timestamp.fromDate(now.add(const Duration(minutes: 170))),
    });
    await expectLater(service.extendSession('session', byUid: 'customer'), throwsException);
  });
}
