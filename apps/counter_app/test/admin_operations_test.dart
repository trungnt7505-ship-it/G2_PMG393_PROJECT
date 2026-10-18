import 'dart:async';
import 'package:core/core.dart';
import 'package:counter_app/screens/manager_admin_screen.dart';
import 'package:counter_app/widgets/app_config_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingConfigService extends ConfigService {
  AppConfig? saved;
  Object? failure;
  @override
  Future<void> save(AppConfig config, {AppConfig? expected}) async {
    if (failure != null) throw failure!;
    saved = config;
  }
}

void main() {
  final now = DateTime(2026, 10, 18, 10);
  final manager = UserModel(
      id: 'manager',
      role: 'manager',
      displayName: 'Quản lý',
      phone: '',
      email: '',
      createdAt: now);

  void laptop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Configuration validates values and saves every existing field',
      (tester) async {
    laptop(tester);
    final service = RecordingConfigService();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(manager)),
          configServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: AppConfigForm(config: AppConfig.defaultConfig)))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('config_pointEarnVnd')), '0');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save_config')));
    await tester.tap(find.byKey(const Key('save_config')));
    await tester.pumpAndSettle();
    expect(service.saved, isNull);
    expect(find.textContaining('pointEarnVnd phải lớn hơn 0'), findsOneWidget);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('config_pointEarnVnd')));
    await tester.enterText(
        find.byKey(const Key('config_pointEarnVnd')), '20000');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save_config')));
    await tester.tap(find.byKey(const Key('save_config')));
    await tester.pumpAndSettle();
    expect(service.saved!.pointEarnVnd, 20000);
    expect(service.saved!.warnMinutes, [15, 5]);
    expect(service.saved!.toMap(), hasLength(14));
    expect(find.text('Đã lưu cấu hình hệ thống.'), findsOneWidget);
  });

  testWidgets('Config save failure preserves the draft for retry',
      (tester) async {
    laptop(tester);
    final service = RecordingConfigService()
      ..failure = StateError('Không có quyền lưu');
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(manager)),
          configServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: AppConfigForm(config: AppConfig.defaultConfig)))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('config_sessionMinutes')), '90');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save_config')));
    await tester.tap(find.byKey(const Key('save_config')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không có quyền lưu'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const Key('config_sessionMinutes')))
            .controller!
            .text,
        '90');
  });

  for (final state in ['data', 'loading', 'error']) {
    testWidgets('Statistics show real sessions/invoices and handle $state',
        (tester) async {
      laptop(tester);
      final controller = StreamController<List<SessionModel>>.broadcast();
      addTearDown(controller.close);
      SessionModel session(String id, String status) => SessionModel(
          id: id,
          tableId: 'table',
          tableName: 'Bàn',
          customerName: 'Khách',
          openedBy: 'counter',
          openedByRole: 'counter',
          startedAt: now,
          expiresAt: now,
          status: status);
      final payment = PaymentModel(
          id: 'payment',
          sessionId: 'session',
          tableId: 'table',
          tableName: 'Bàn',
          cashierId: 'counter',
          method: 'cash',
          subtotal: 90000,
          total: 90000,
          paidAt: now);
      await tester.pumpWidget(ProviderScope(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(manager)),
        menuItemsProvider.overrideWith((ref) => Stream.value([])),
        appConfigProvider
            .overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
        todayPaymentsProvider.overrideWith((ref) => Stream.value([payment])),
        todayNoShowsProvider.overrideWith((ref) => Stream.value([])),
        todaySessionsProvider.overrideWith((ref) => state == 'loading'
            ? controller.stream
            : state == 'error'
                ? Stream.error(StateError('offline'))
                : Stream.value([
                    session('one', 'active'),
                    session('two', 'paid'),
                    session('three', 'cancelled')
                  ])),
      ], child: const MaterialApp(home: ManagerAdminScreen())));
      // The loading state intentionally has an animated spinner.
      await tester.pump();
      await tester.tap(find.text('Thống kê & Dữ liệu mẫu'));
      await tester.pump();
      if (state == 'loading') {
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      } else {
        await tester.pumpAndSettle();
      }
      if (state == 'data') {
        expect(find.text('2 phiên'), findsOneWidget);
        expect(find.text('1 đơn'), findsOneWidget);
        expect(find.textContaining('90.000'), findsOneWidget);
      } else if (state == 'error') {
        expect(find.textContaining('Không tải được thống kê'), findsOneWidget);
        expect(find.text('0 đơn'), findsNothing);
        expect(find.text('Thử lại'), findsOneWidget);
      } else {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('0 đơn'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
