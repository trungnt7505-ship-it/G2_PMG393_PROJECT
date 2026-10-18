import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('Saved duration and extension apply without changing an existing expiry',
      () async {
    final config = AppConfig.defaultConfig
        .copyWith(sessionMinutes: 90, extendStepMinutes: 20);
    await ConfigService(firestore: db).save(config);
    await db.doc('tables/table').set(const TableModel(
            id: 'table',
            name: 'Bàn',
            zone: 'Tầng 1',
            capacity: 2,
            qrSecret: 'secret')
        .toMap());
    final service = SessionService(firestore: db);
    final id = await service.openSession(
        tableId: 'table', openedBy: 'cashier', openedByRole: 'counter');
    final before =
        SessionModel.fromMap((await db.doc('sessions/$id').get()).data()!, id);
    expect(before.baseMinutes, 90);
    await ConfigService(firestore: db)
        .save(config.copyWith(sessionMinutes: 60));
    final unchanged =
        SessionModel.fromMap((await db.doc('sessions/$id').get()).data()!, id);
    expect(unchanged.expiresAt, before.expiresAt);
    expect(await service.extendSession(id, byUid: 'cashier'), 20);
    final after =
        SessionModel.fromMap((await db.doc('sessions/$id').get()).data()!, id);
    expect(after.expiresAt.difference(before.expiresAt).inMinutes, 20);
  });

  test(
      'Reservation duration, hold time and booking limits follow saved configuration',
      () async {
    final config = AppConfig.defaultConfig
        .copyWith(sessionMinutes: 90, reservationHoldMinutes: 10);
    await ConfigService(firestore: db).save(config);
    final now = ClockService.instance.serverNow;
    final start = now.add(const Duration(hours: 2));
    final draft = ReservationModel(
        id: '',
        customerId: 'customer',
        customerName: 'Khách',
        phone: '090',
        tableId: 'table',
        tableName: 'Bàn',
        partySize: 2,
        startTime: start,
        endTime: start,
        holdUntil: start,
        createdAt: now);
    final service = ReservationService(firestore: db);
    final id = await service.createReservation(draft);
    final saved = ReservationModel.fromMap(
        (await db.doc('reservations/$id').get()).data()!, id);
    expect(saved.endTime.difference(start).inMinutes, 90);
    expect(saved.holdUntil.difference(start).inMinutes, 10);
    await expectLater(
        service.createReservation(
            draft.copyWith(startTime: start.add(const Duration(days: 8)))),
        throwsStateError);
    expect(
        (await db.collection('tables/table/slots').get()).docs, hasLength(5));
  });

  test('Early release follows config and cannot reopen a closed session',
      () async {
    final now = ClockService.instance.serverNow;
    await ConfigService(firestore: db)
        .save(AppConfig.defaultConfig.copyWith(earlyReleaseMinMinutes: 60));
    await db.doc('sessions/session').set(SessionModel(
            id: 'session',
            tableId: 'table',
            tableName: 'Bàn',
            customerId: 'customer',
            customerName: 'Khách',
            openedBy: 'cashier',
            openedByRole: 'counter',
            startedAt: now,
            expiresAt: now.add(const Duration(minutes: 40)))
        .toMap());
    final service = SessionService(firestore: db);
    await expectLater(
        service.requestEarlyRelease('session', customerId: 'customer'),
        throwsException);
    await ConfigService(firestore: db).save(AppConfig.defaultConfig);
    await service.requestEarlyRelease('session', customerId: 'customer');
    expect((await db.doc('sessions/session').get()).data()!['earlyReleased'],
        isTrue);
    await db.doc('sessions/session').update({'status': 'paid'});
    await expectLater(
        service.requestEarlyRelease('session', customerId: 'customer'),
        throwsStateError);
    expect((await db.doc('sessions/session').get()).data()!['status'], 'paid');
  });

  test('Counter display threshold can follow a new configuration', () {
    final now = ClockService.instance.serverNow;
    const table = TableModel(
        id: 'table', name: 'Bàn', zone: '', capacity: 2, qrSecret: '');
    final session = SessionModel(
        id: 'session',
        tableId: 'table',
        tableName: 'Bàn',
        customerName: 'Khách',
        openedBy: 'counter',
        openedByRole: 'counter',
        startedAt: now,
        expiresAt: now.add(const Duration(minutes: 18)));
    final service = SessionService(firestore: db);
    expect(service.computeDisplayStatus(table, session, null, now),
        TableDisplayStatus.using);
    expect(
        service.computeDisplayStatus(table, session, null, now,
            config: AppConfig.defaultConfig.copyWith(warnMinutes: [20, 5])),
        TableDisplayStatus.expiring);
  });
}
