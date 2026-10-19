import 'package:core/core.dart';
import 'package:counter_app/widgets/order_queue_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TakeawayOrders extends OrderService {
  final List<OrderModel> orders;
  TakeawayOrders(this.orders);
  @override
  Stream<List<OrderModel>> watchAllOrdersByStatuses(
          List<OrderStatus> statuses) =>
      Stream.value(orders);
}

class TakeawayPayment extends PaymentService {
  int calls = 0;
  String? paidOrderId;
  @override
  Future<PaymentModel> payTakeaway(
      {required String orderId,
      required String cashierId,
      required PaymentMethod method,
      String? customerId,
      int pointsUsed = 0,
      int? expectedSubtotal,
      AppConfig? expectedConfig}) async {
    calls++;
    paidOrderId = orderId;
    return PaymentModel(
        id: 'receipt',
        sessionId: 'takeaway_orders',
        tableId: 'takeaway',
        tableName: 'Mang đi',
        cashierId: cashierId,
        method: method.name,
        subtotal: 100000,
        total: 100000,
        paidAt: DateTime(2026));
  }

  @override
  Future<List<OrderItemModel>> getPaymentItems(String paymentId) async =>
      const [
        OrderItemModel(
            itemId: 'coffee', name: 'Cà phê', unitPrice: 100000, qty: 1)
      ];
}

void main() {
  testWidgets(
      'Served unpaid takeaway stays visible and can be paid on a laptop',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026);
    OrderModel order(String id, String? paymentId) => OrderModel(
        id: id,
        sessionId: 'takeaway_orders',
        tableId: 'takeaway',
        tableName: 'Mang đi',
        type: 'takeaway',
        status: 'served',
        items: const [
          OrderItemModel(
              itemId: 'coffee', name: 'Cà phê', unitPrice: 100000, qty: 1)
        ],
        createdBy: 'counter',
        createdByRole: 'counter',
        total: 100000,
        createdAt: now,
        updatedAt: now,
        paymentId: paymentId);
    final service = TakeawayPayment();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          orderServiceProvider.overrideWithValue(TakeawayOrders([
            order('unpaid', null),
            order('paid', 'old_receipt'),
            order('ready_paid', 'ready_receipt').copyWith(status: 'ready')
          ])),
          paymentServiceProvider.overrideWithValue(service),
          appConfigProvider
              .overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
          currentUserProvider.overrideWith((ref) => Stream.value(UserModel(
              id: 'cashier',
              role: 'counter',
              displayName: 'Thu ngân',
              phone: '',
              email: '',
              createdAt: now))),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(width: 550, child: OrderQueuePanel()))))));
    await tester.pumpAndSettle();
    expect(find.text('Thu tiền'), findsOneWidget);
    expect(find.text('Đã phục vụ • Chưa thu tiền'), findsOneWidget);
    expect(find.text('Pha xong • Đã thu tiền'), findsOneWidget);
    expect(find.text('Đã phục vụ'), findsOneWidget);
    await tester.tap(find.text('Thu tiền'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('confirm_payment_button'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(service.paidOrderId, 'unpaid');
    expect(find.text('CAFE SYSTEM - HÓA ĐƠN'), findsOneWidget);
    expect(find.text('1x Cà phê'), findsOneWidget);
    expect(find.text('In hóa đơn'), findsNothing);
  });
}
