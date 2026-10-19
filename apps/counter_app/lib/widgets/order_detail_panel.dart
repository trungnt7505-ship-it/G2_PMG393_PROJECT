import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';
import '../dialogs/payment_checkout_modal.dart';
import '../viewmodels/pos_dashboard_viewmodel.dart';

/// Cột 3: Chi tiết hóa đơn của bàn đang chọn & Thông báo yêu cầu hỗ trợ (Requests).
class OrderDetailPanel extends ConsumerWidget {
  const OrderDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFmt = NumberFormat('#,###', 'vi_VN');
    final timeFmt = DateFormat('HH:mm');

    final dashboardState = ref.watch(posDashboardViewModelProvider);
    final selectedTableId = dashboardState.selectedTableId;

    if (selectedTableId == null) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Chọn một bàn trên sơ đồ để xem chi tiết',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final tablesAsync = ref.watch(allTablesProvider);
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final requestsAsync = ref.watch(openRequestsProvider);
    final error =
        tablesAsync.error ?? sessionsAsync.error ?? requestsAsync.error;
    if (error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Không tải được chi tiết bàn: $error'),
        TextButton(
            onPressed: () {
              ref.invalidate(allTablesProvider);
              ref.invalidate(activeSessionsProvider);
              ref.invalidate(openRequestsProvider);
            },
            child: const Text('Thử lại')),
      ]));
    }
    if (tablesAsync.isLoading ||
        sessionsAsync.isLoading ||
        requestsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tables = tablesAsync.requireValue;
    final table = tables.cast<TableModel?>().firstWhere(
          (t) => t?.id == selectedTableId,
          orElse: () => null,
        );

    final activeSessions = sessionsAsync.requireValue;
    final activeSession = activeSessions.cast<SessionModel?>().firstWhere(
          (s) => s?.tableId == selectedTableId && s!.isActive,
          orElse: () => null,
        );

    final openRequests = requestsAsync.requireValue;
    final tableRequests =
        openRequests.where((r) => r.tableId == selectedTableId).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bàn
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    table?.name ?? selectedTableId,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${table?.zone ?? ''} • ${table?.capacity ?? 0} chỗ',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              if (activeSession != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeSession.status == 'billing'
                        ? Colors.red.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    activeSession.status == 'billing'
                        ? 'Yêu cầu tính tiền'
                        : 'Đang sử dụng',
                    style: TextStyle(
                      color: activeSession.status == 'billing'
                          ? Colors.red.shade900
                          : Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 20),

          // Yêu cầu hỗ trợ từ bàn (Requests)
          if (tableRequests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active,
                          color: Colors.amber, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Yêu cầu hỗ trợ cần xử lý:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...tableRequests.map((req) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '• ${req.type == 'call_waiter' ? 'Khách gọi phục vụ' : req.type == 'request_bill' ? 'Khách xin tính tiền' : req.type == 'release_table' ? 'Yêu cầu nhả bàn' : 'Trả bàn sớm'}: ${req.message}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(posDashboardViewModelProvider.notifier)
                                  .resolveRequest(req.id);
                            },
                            child: const Text('Xong',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Thông tin phiên & Danh sách món
          if (activeSession == null) ...[
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 48, color: Colors.green),
                    const SizedBox(height: 8),
                    Text(
                      'Bàn đang ${table?.status == 'needs_cleaning' ? 'chờ dọn dẹp' : 'trống'}',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Thông tin khách
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Khách: ${activeSession.customerName}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'Bắt đầu: ${timeFmt.format(activeSession.startedAt)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Đồng hồ đếm ngược
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text('Thời gian còn lại:',
                    style: TextStyle(fontSize: 13)),
                CountdownTimerWidget(
                  expiresAt: activeSession.expiresAt,
                  fontSize: 16,
                ),
              ],
            ),
            const Divider(height: 20),

            // Chi tiết các món đã gọi trong phiên
            const Text(
              'Danh sách món gọi:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 300,
              child: Consumer(
                builder: (context, ref, _) {
                  final sessionOrdersAsync =
                      ref.watch(sessionOrdersProvider(activeSession.id));

                  return sessionOrdersAsync.when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return const Center(
                            child: Text('Chưa có món nào được gọi.'));
                      }

                      final allItems = orders
                          .where((o) =>
                              o.orderStatus != OrderStatus.cancelled &&
                              o.orderStatus != OrderStatus.pending)
                          .expand((o) => o.items)
                          .toList();
                      final hasPending = orders
                          .any((o) => o.orderStatus == OrderStatus.pending);

                      return Column(
                        children: [
                          if (hasPending)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: Colors.orange.shade300),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber,
                                      size: 16, color: Colors.orange),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Còn đơn chờ duyệt! Cần duyệt trước khi thanh toán.',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: allItems.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = allItems[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${item.qty}x ${item.name}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                  subtitle: item.selectedOptions.isNotEmpty
                                      ? Text(
                                          item.selectedOptions
                                              .map((o) => o.choiceName)
                                              .join(', '),
                                          style: const TextStyle(fontSize: 11),
                                        )
                                      : null,
                                  trailing: Text(
                                    '${currencyFmt.format(item.totalPrice)} đ',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Lỗi: $e')),
                  );
                },
              ),
            ),
            const Divider(height: 20),

            // Tổng tạm tính
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'TỔNG TẠM TÍNH:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${currencyFmt.format(activeSession.subtotal)} đ',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nút mở modal thanh toán
            ElevatedButton.icon(
              onPressed: () {
                final orders =
                    ref.read(sessionOrdersProvider(activeSession.id)).value ??
                        [];
                final allItems = orders
                    .where((o) =>
                        o.orderStatus != OrderStatus.cancelled &&
                        o.orderStatus != OrderStatus.pending)
                    .expand((o) => o.items)
                    .toList();

                showDialog(
                  context: context,
                  builder: (ctx) => PaymentCheckoutModal(
                    session: activeSession,
                    items: allItems,
                  ),
                );
              },
              icon: const Icon(Icons.payment),
              label: const Text(
                'Thanh toán & Đóng bàn',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      )),
    );
  }
}
