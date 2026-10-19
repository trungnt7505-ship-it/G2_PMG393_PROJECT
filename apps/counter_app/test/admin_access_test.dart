import 'package:core/core.dart';
import 'package:counter_app/routing/app_router.dart';
import 'package:counter_app/viewmodels/auth_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class SignedInAuth extends AuthViewModel {
  SignedInAuth(UserModel? user) : super(AuthService()) {
    state = AuthState(user: user);
  }
}

class EmptyOrders extends OrderService {
  @override
  Stream<List<OrderModel>> watchAllOrdersByStatuses(
          List<OrderStatus> statuses) =>
      Stream.value([]);
}

void main() {
  for (final role in ['counter', 'manager', 'customer', 'anonymous']) {
    testWidgets('Direct admin access for $role', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final user = role == 'anonymous'
          ? null
          : UserModel(
              id: 'test_$role',
              role: role,
              displayName: role,
              phone: '',
              email: '',
              createdAt: DateTime(2026),
            );
      final container = ProviderContainer(overrides: [
        authViewModelProvider.overrideWith((ref) => SignedInAuth(user)),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        allTablesProvider.overrideWith((ref) => Stream.value([])),
        activeSessionsProvider.overrideWith((ref) => Stream.value([])),
        todayConfirmedReservationsProvider
            .overrideWith((ref) => Stream.value([])),
        orderServiceProvider.overrideWithValue(EmptyOrders()),
        menuItemsProvider.overrideWith((ref) => Stream.value([])),
        appConfigProvider
            .overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
        todaySessionsProvider.overrideWith((ref) => Stream.value([])),
        todayPaymentsProvider.overrideWith((ref) => Stream.value([])),
        todayNoShowsProvider.overrideWith((ref) => Stream.value([])),
      ]);
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(
            builder: (context, ref, child) =>
                MaterialApp.router(routerConfig: ref.watch(appRouterProvider))),
      ));
      await tester.pumpAndSettle();
      final activeRouter = container.read(appRouterProvider);
      activeRouter.go('/admin');
      await tester.pumpAndSettle();
      expect(
          activeRouter.routerDelegate.currentConfiguration.uri.path,
          role == 'manager'
              ? '/admin'
              : role == 'counter'
                  ? '/pos'
                  : '/login');
      await tester.pumpWidget(const SizedBox());
      activeRouter.dispose();
      if (!identical(router, activeRouter)) router.dispose();
      container.dispose();
    });
  }
}
