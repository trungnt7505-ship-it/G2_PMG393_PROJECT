import 'dart:async';
import 'package:core/core.dart';
import 'package:counter_app/dialogs/invoice_preview_dialog.dart';
import 'package:counter_app/dialogs/saved_invoice_dialog.dart';
import 'package:counter_app/screens/pos_dashboard_screen.dart';
import 'package:counter_app/viewmodels/pos_dashboard_viewmodel.dart';
import 'package:counter_app/widgets/table_map_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class UXOrders extends OrderService {
  final Completer<void> result = Completer();
  int calls = 0;
  @override
  Future<void> approveOrder(String sessionId, String orderId) {
    calls++;
    return result.future;
  }

  @override
  Stream<List<OrderModel>> watchAllOrdersByStatuses(
          List<OrderStatus> statuses) =>
      Stream.value([]);
}

class ReceiptService extends PaymentService {
  int attempts = 0;
  @override
  Future<List<OrderItemModel>> getPaymentItems(String paymentId) async {
    if (++attempts == 1) throw StateError('Mất kết nối');
    return const [
      OrderItemModel(
          itemId: 'coffee', name: 'Cà phê', unitPrice: 100000, qty: 1)
    ];
  }
}

void main() {
  final now = DateTime(2026, 10, 19);
  final payment = PaymentModel(
      id: 'very_long_payment_id_for_layout_12345678901234567890',
      sessionId: 'session',
      tableId: 'table',
      tableName: 'Bàn 01 • Khu sân vườn',
      cashierId: 'cashier_uid_with_long_identifier_1234567890',
      method: 'cash',
      subtotal: 100000,
      total: 100000,
      paidAt: now);

  void resize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final size in [
    const Size(1366, 768),
    const Size(1024, 600),
    const Size(800, 600)
  ]) {
    testWidgets('POS fits $size and opens a selected table', (tester) async {
      resize(tester, size);
      final service = UXOrders();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(UserModel(
            id: 'manager',
            role: 'manager',
            displayName: 'Quản lý thử nghiệm có tên dài',
            phone: '',
            email: '',
            createdAt: now))),
        appConfigProvider
            .overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
        allTablesProvider.overrideWith((ref) => Stream.value(const [
              TableModel(
                  id: 'table',
                  name: 'Bàn Demo 01 • Sân vườn',
                  zone: 'Demo tích hợp',
                  capacity: 4,
                  qrSecret: 'test')
            ])),
        activeSessionsProvider.overrideWith((ref) => Stream.value([
              SessionModel(
                  id: 'session',
                  tableId: 'table',
                  tableName: 'Bàn Demo 01',
                  customerName: 'Khách có tên dài để kiểm tra giao diện',
                  openedBy: 'counter',
                  openedByRole: 'counter',
                  status: 'billing',
                  startedAt: now,
                  expiresAt: ClockService.instance.serverNow
                      .add(const Duration(hours: 1)),
                  subtotal: 100000)
            ])),
        todayConfirmedReservationsProvider
            .overrideWith((ref) => Stream.value([])),
        openRequestsProvider.overrideWith((ref) => Stream.value(List.generate(
            8,
            (i) => RequestModel(
                id: 'req$i',
                sessionId: 'session',
                tableId: 'table',
                tableName: 'Bàn',
                type: 'request_bill',
                message:
                    'Khách cần thanh toán, nội dung yêu cầu dài để kiểm tra cuộn',
                createdBy: 'customer',
                createdAt: now)))),
        sessionOrdersProvider.overrideWith((ref, id) => Stream.value([])),
        orderServiceProvider.overrideWithValue(service),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PosDashboardScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Demo tích hợp'), findsOneWidget);
      await tester.tap(find.text('Bàn Demo 01 • Sân vườn'));
      await tester.pumpAndSettle();
      expect(find.text('Yêu cầu hỗ trợ cần xử lý:'), findsOneWidget);
      await tester.ensureVisible(find.text('Thanh toán & Đóng bàn'));
      await tester.pump();
      expect(find.text('Thanh toán & Đóng bàn').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }

  testWidgets('Long invoice remains scrollable and has no print action',
      (tester) async {
    resize(tester, const Size(800, 480));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: InvoicePreviewDialog(
                payment: payment,
                items: List.generate(
                    30,
                    (i) => OrderItemModel(
                            itemId: '$i',
                            name: 'Món số $i với tên dài',
                            unitPrice: 10000,
                            qty: 1,
                            note: 'Ít đường, ít đá',
                            selectedOptions: const [
                              SelectedOption(
                                  groupName: 'Size', choiceName: 'Lớn')
                            ]))))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đóng'));
    expect(find.text('Đóng').hitTestable(), findsOneWidget);
    expect(find.text('In hóa đơn'), findsNothing);
  });

  testWidgets('Receipt retries loading without another payment',
      (tester) async {
    final service = ReceiptService();
    await tester.pumpWidget(ProviderScope(
        overrides: [paymentServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
            home: Scaffold(body: SavedInvoiceDialog(payment: payment)))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(service.attempts, 2);
    expect(find.text('CAFE SYSTEM - HÓA ĐƠN'), findsOneWidget);
  });

  test('Repeated clicks while an action runs call the service once', () async {
    final service = UXOrders();
    final vm = PosDashboardViewModel(
        sessionService: SessionService(), orderService: service);
    final first = vm.approveOrder('session', 'order');
    await vm.approveOrder('session', 'order');
    expect(service.calls, 1);
    service.result.completeError(StateError('Không có quyền'));
    await first;
    expect(vm.state.isActionLoading, isFalse);
    expect(vm.state.actionMessage, contains('Không có quyền'));
    vm.dispose();
  });

  testWidgets('Empty Firestore shows no fabricated tables', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      allTablesProvider.overrideWith((ref) => Stream.value([])),
      activeSessionsProvider.overrideWith((ref) => Stream.value([])),
      todayConfirmedReservationsProvider
          .overrideWith((ref) => Stream.value([])),
      appConfigProvider
          .overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
    ], child: const MaterialApp(home: Scaffold(body: TableMapPanel()))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có bàn.'), findsOneWidget);
    expect(find.text('Bàn 01'), findsNothing);
  });
}
