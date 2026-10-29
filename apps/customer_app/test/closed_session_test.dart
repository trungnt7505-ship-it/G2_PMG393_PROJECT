import 'package:core/core.dart';
import 'package:customer_app/repositories/customer_repository.dart';
import 'package:customer_app/screens/session/active_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ScreenAuth implements AuthService {
  @override
  String? get currentUid => 'customer';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class ScreenRepository implements CustomerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  for (final status in ['paid', 'cancelled']) {
    testWidgets('Closed session $status never shows an active countdown', (tester) async {
      await tester.pumpWidget(ProviderScope(overrides: [
        authServiceProvider.overrideWithValue(ScreenAuth()),
        customerRepositoryProvider.overrideWithValue(ScreenRepository()),
        appConfigProvider.overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
        menuItemsProvider.overrideWith((ref) => Stream.value([])),
        sessionOrdersProvider('session').overrideWith((ref) => Stream.value([])),
        sessionStreamProvider('session').overrideWith((ref) => Stream.value(SessionModel(
          id: 'session', tableId: 'table', tableName: 'Demo', customerName: 'Khách',
          openedBy: 'counter', openedByRole: 'counter', startedAt: DateTime(2026),
          expiresAt: DateTime(2027), status: status,
        ))),
      ], child: const MaterialApp(home: ActiveSessionScreen(sessionId: 'session'))));
      await tester.pumpAndSettle();
      expect(find.text(status == 'paid' ? 'Đã thanh toán' : 'Đã hủy'), findsOneWidget);
      expect(find.text('Phiên bàn đã kết thúc'), findsOneWidget);
      expect(find.byType(CountdownTimerWidget), findsNothing);
      expect(find.text('Đang hoạt động'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
