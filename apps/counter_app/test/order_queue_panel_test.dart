import 'package:core/core.dart';
import 'package:counter_app/widgets/order_queue_panel.dart';
import 'package:counter_app/viewmodels/pos_dashboard_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class EmptyOrderService extends OrderService {
  int subscriptions = 0;

  @override
  Stream<List<OrderModel>> watchAllOrdersByStatuses(List<OrderStatus> statuses) {
    subscriptions++;
    return Stream.value([]);
  }
}

void main() {
  testWidgets('Payment filter includes seated customers requesting a bill', (tester) async {
    final now = DateTime.now();
    final container = ProviderContainer(overrides: [
      orderServiceProvider.overrideWithValue(EmptyOrderService()),
      activeSessionsProvider.overrideWith((ref) => Stream.value([SessionModel(id:'s',tableId:'t',tableName:'Bàn 01',customerName:'Khách A',openedBy:'w',openedByRole:'waiter',startedAt:now,expiresAt:now.add(const Duration(hours:2)),subtotal:50000)])),
      openRequestsProvider.overrideWith((ref) => Stream.value([RequestModel(id:'r',sessionId:'s',tableId:'t',tableName:'Bàn 01',type:'request_bill',createdBy:'c',createdAt:now)])),
    ]);
    addTearDown(container.dispose);
    container.read(posDashboardViewModelProvider.notifier).filterOrder('Chờ thanh toán');
    await tester.pumpWidget(UncontrolledProviderScope(container:container,child:const MaterialApp(home:Scaffold(body:OrderQueuePanel()))));
    await tester.pumpAndSettle();
    expect(find.text('Bàn 01 · Khách A'),findsOneWidget);
    expect(find.text('Thu tiền'),findsOneWidget);
  });
  testWidgets('Empty queue finishes loading and keeps its stream on filter changes',
      (tester) async {
    final service = EmptyOrderService();
    final container = ProviderContainer(overrides: [
      orderServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: OrderQueuePanel())),
    ));
    // Bound pumps so a repeated loading cycle fails instead of hanging.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Hàng đợi pha chế hiện đang trống.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(service.subscriptions, 1);

    container.read(posDashboardViewModelProvider.notifier).filterOrder('Sẵn sàng');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hàng đợi pha chế hiện đang trống.'), findsOneWidget);
    expect(service.subscriptions, 1);
  });
}
