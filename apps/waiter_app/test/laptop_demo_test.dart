import 'dart:async';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waiter_app/main.dart';
import 'package:waiter_app/routing/app_router.dart';
import 'package:waiter_app/screens/waiter_main_screen.dart';
import 'package:waiter_app/screens/floor_map_screen.dart';
import 'package:waiter_app/viewmodels/waiter_auth_viewmodel.dart';

class TestAuth implements AuthService {
  int attempts = 0;
  final Completer<UserModel> response = Completer();
  @override
  Future<UserModel> signInWithEmail(String email, String password,
      {required List<UserRole> allowedRoles}) {
    attempts++;
    expect(allowedRoles, isNot(contains(UserRole.customer)));
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Failed Firebase login stays failed and repeated clicks do not retry',
      () async {
    final auth = TestAuth();
    final vm = WaiterAuthViewModel(auth);
    final first = vm.signIn('waiter1@cafe.com', '123456');
    expect(await vm.signIn('waiter1@cafe.com', '123456'), isFalse);
    auth.response.completeError(StateError('Invalid credentials'));
    expect(await first, isFalse);
    expect(auth.attempts, 1);
    expect(vm.state.hasError, isTrue);
    vm.dispose();
  });

  testWidgets('Startup offers retry after connection error', (tester) async {
    int attempts = 0;
    Future<void> fail() async {
      attempts++;
      throw StateError('offline');
    }

    await tester.pumpWidget(WaiterStartup(initialize: fail));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('Customer with persisted login cannot enter waiter route',
      (tester) async {
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(TestAuth()),
      currentUserProvider.overrideWith((ref) => Stream.value(UserModel(
            id: 'customer',
            role: 'customer',
            displayName: 'Khách',
            phone: '',
            email: '',
            createdAt: DateTime(2026),
          ))),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const WaiterApp()));
    await tester.pumpAndSettle();
    expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/login');
    expect(find.text('ĐĂNG NHẬP THAO TÁC'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.read(appRouterProvider).dispose();
    container.dispose();
  });

  testWidgets(
      'Failed session stream shows retry instead of actionable empty tables',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionServiceProvider.overrideWithValue(
          SessionService(firestore: FakeFirebaseFirestore())),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
      appConfigProvider
          .overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
      allTablesProvider.overrideWith((ref) => Stream.value(const [])),
      activeSessionsProvider
          .overrideWith((ref) => Stream.error(StateError('permission denied'))),
      todayConfirmedReservationsProvider
          .overrideWith((ref) => Stream.value([])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FloorMapScreen())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Chưa có dữ liệu bàn trong hệ thống.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final size in [
    const Size(1366, 768),
    const Size(1024, 600),
    const Size(800, 600)
  ]) {
    testWidgets('Waiter fits laptop $size and shows overdue alert/task tab',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(TestAuth()),
        sessionServiceProvider.overrideWithValue(SessionService(firestore: db)),
        orderServiceProvider.overrideWithValue(OrderService(firestore: db)),
        currentUserProvider.overrideWith((ref) => Stream.value(UserModel(
              id: 'waiter',
              role: 'waiter',
              displayName:
                  'Nhân viên với tên rất dài để kiểm tra bố cục laptop',
              phone: '',
              email: '',
              createdAt: DateTime(2026),
            ))),
        appConfigProvider
            .overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
        allTablesProvider.overrideWith((ref) => Stream.value(const [
              TableModel(
                id: 't',
                name: 'Bàn laptop',
                zone: 'Demo tích hợp',
                capacity: 4,
                qrSecret: 'test',
              )
            ])),
        activeSessionsProvider.overrideWith((ref) => Stream.value([
              SessionModel(
                id: 's',
                tableId: 't',
                tableName: 'Bàn laptop',
                customerName: 'Khách demo',
                openedBy: 'waiter',
                openedByRole: 'waiter',
                startedAt: DateTime(2026),
                expiresAt: ClockService.instance.serverNow
                    .subtract(const Duration(minutes: 1)),
              )
            ])),
        todayConfirmedReservationsProvider
            .overrideWith((ref) => Stream.value([])),
        openRequestsProvider.overrideWith((ref) => Stream.value([])),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WaiterMainScreen())));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Cảnh báo bàn:'), findsOneWidget);
      expect(find.text('Bàn laptop'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tác vụ'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Trung tâm Tác vụ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
