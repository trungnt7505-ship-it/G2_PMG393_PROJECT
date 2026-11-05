import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Warns once, does not expire early, and rearms after extension', () async {
    final service = AlarmService.instance;
    service.resetSessionAlarms('alarm-test');
    final events = <SessionAlarm>[];
    final subscription = service.alerts.listen(events.add);
    addTearDown(subscription.cancel);
    final now = DateTime.now();
    final session = SessionModel(
      id: 'alarm-test', tableId: 't', tableName: 'Bàn 01',
      openedBy: 'c', openedByRole: 'customer', startedAt: now,
      expiresAt: now.add(const Duration(seconds: 40)),
    );
    await service.syncAlarmsForSession(session);
    await service.syncAlarmsForSession(session);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(events.single.title, contains('5 phút'));
    expect(service.firedBySession[session.id], isNot(contains(0)));

    final expired = session.copyWith(expiresAt: now.subtract(const Duration(seconds: 1)));
    await service.syncAlarmsForSession(expired);
    await Future<void>.delayed(Duration.zero);
    expect(events.last.title, 'Hết giờ dùng bàn!');

    await service.syncAlarmsForSession(session.copyWith(
      expiresAt: now.add(const Duration(minutes: 10)),
    ));
    await Future<void>.delayed(Duration.zero);
    expect(events.last.title, contains('15 phút'));
    service.resetSessionAlarms(session.id);
  });
}
