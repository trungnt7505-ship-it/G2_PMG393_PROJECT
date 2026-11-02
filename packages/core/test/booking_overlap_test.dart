import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ReservationService service;
  late DateTime start;
  ReservationModel draft(String customer, String table, DateTime at) =>
      ReservationModel(
          id: '',
          customerId: customer,
          customerName: customer,
          phone: '',
          tableId: table,
          tableName: table,
          partySize: 2,
          startTime: at,
          endTime: at.add(const Duration(hours: 2)),
          holdUntil: at.add(const Duration(minutes: 15)),
          createdAt: at);
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = ReservationService(firestore: db);
    start = DateTime.now().add(const Duration(days: 1));
    for (final table in ['a', 'b']) {
      await db.doc('tables/$table').set({
        'name': table,
        'capacity': 4,
        'status': 'available',
        'zone': 'Test',
        'qrSecret': 'test'
      });
    }
  });
  test('Different customers cannot book same table eight minutes apart',
      () async {
    await service.createReservation(draft('one', 'a', start));
    await expectLater(
        service.createReservation(
            draft('two', 'a', start.add(const Duration(minutes: 8)))),
        throwsStateError);
    final available = await service.getAvailableTables(
        startTime: start.add(const Duration(minutes: 8)), partySize: 2);
    expect(available.map((t) => t.id), ['b']);
    expect((await db.collection('reservations').get()).docs, hasLength(1));
  });
  test('Same customer cannot book two tables with overlapping intervals',
      () async {
    await service.createReservation(draft('one', 'a', start));
    await expectLater(
        service.createReservation(
            draft('one', 'b', start.add(const Duration(minutes: 8)))),
        throwsStateError);
    expect((await db.collection('tables/b/slots').get()).docs, isEmpty);
  });
  test('Separate times and separate customers at different tables are allowed',
      () async {
    await service.createReservation(draft('one', 'a', start));
    await service.createReservation(draft('two', 'b', start));
    await service.createReservation(
        draft('one', 'a', start.add(const Duration(hours: 3))));
    expect((await db.collection('reservations').get()).docs, hasLength(3));
  });
  test('Cancelled reservation releases customer and table', () async {
    final id = await service.createReservation(draft('one', 'a', start));
    await service.cancelReservation(id);
    await service.createReservation(
        draft('one', 'a', start.add(const Duration(minutes: 8))));
    expect((await db.collection('reservations').get()).docs, hasLength(2));
  });
  test('Active customer session blocks a different table', () async {
    await db.doc('sessions/current').set(SessionModel(
            id: 'current',
            tableId: 'a',
            tableName: 'a',
            customerId: 'one',
            customerName: 'one',
            openedBy: 'staff',
            openedByRole: 'counter',
            startedAt: start,
            expiresAt: start.add(const Duration(hours: 2)))
        .toMap());
    await expectLater(
        service.createReservation(draft('one', 'b', start)), throwsStateError);
  });
}
