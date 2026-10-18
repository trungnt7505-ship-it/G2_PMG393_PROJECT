import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';
import '../dialogs/takeaway_order_dialog.dart';
import '../dialogs/payment_checkout_modal.dart';
import '../viewmodels/pos_dashboard_viewmodel.dart';

/// Cột 2: Hàng đợi pha chế & quản lý đơn gọi món (Kitchen / Bar Queue).
/// Cho phép duyệt đơn khách đặt, chuyển trạng thái confirmed -> preparing -> ready,
/// và tạo nhanh đơn mang về (Takeaway).
class OrderQueuePanel extends ConsumerWidget {
  const OrderQueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFmt = NumberFormat('#,###', 'vi_VN');
    final timeFmt = DateFormat('HH:mm');

    // Lắng nghe tất cả các đơn hàng chưa hoàn tất phục vụ
    final ordersAsync = ref.watch(
      ordersByStatusesProvider(const [
        OrderStatus.pending,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.served,
      ]),
    );

    final dashboardState = ref.watch(posDashboardViewModelProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Nút tạo đơn Takeaway
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.soup_kitchen, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Hàng đợi Pha chế',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const TakeawayOrderDialog(),
                    );
                  },
                  icon: const Icon(Icons.takeout_dining, size: 18),
                  label: const Text('Đơn mang đi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Bộ lọc trạng thái đơn
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                'Tất cả',
                'Chờ duyệt',
                'Đang pha chế',
                'Sẵn sàng',
                'Chờ thanh toán'
              ].map((filter) {
                final isSelected = dashboardState.orderFilter == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    ref
                        .read(posDashboardViewModelProvider.notifier)
                        .filterOrder(filter);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Danh sách đơn hàng
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filteredOrders = orders.where((o) {
                  if (o.orderType == OrderType.takeaway &&
                      o.paymentId != null &&
                      o.orderStatus == OrderStatus.served) {
                    return false;
                  }
                  if (o.orderStatus == OrderStatus.served &&
                      o.orderType != OrderType.takeaway) {
                    return false;
                  }
                  if (dashboardState.orderFilter == 'Chờ thanh toán') {
                    return o.orderType == OrderType.takeaway &&
                        o.paymentId == null &&
                        [OrderStatus.ready, OrderStatus.served]
                            .contains(o.orderStatus);
                  }
                  if (dashboardState.orderFilter == 'Chờ duyệt') {
                    return o.orderStatus == OrderStatus.pending;
                  }
                  if (dashboardState.orderFilter == 'Đang pha chế') {
                    return o.orderStatus == OrderStatus.confirmed ||
                        o.orderStatus == OrderStatus.preparing;
                  }
                  if (dashboardState.orderFilter == 'Sẵn sàng') {
                    return o.orderStatus == OrderStatus.ready;
                  }
                  return true;
                }).toList();

                if (filteredOrders.isEmpty) {
                  return const Center(
                    child: Text('Hàng đợi pha chế hiện đang trống.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];

                    Color statusBgColor;
                    Color statusTextColor;
                    String statusLabel;

                    switch (order.orderStatus) {
                      case OrderStatus.pending:
                        statusBgColor = Colors.orange.shade100;
                        statusTextColor = Colors.orange.shade900;
                        statusLabel = 'Chờ duyệt';
                        break;
                      case OrderStatus.confirmed:
                        statusBgColor = Colors.blue.shade100;
                        statusTextColor = Colors.blue.shade900;
                        statusLabel = 'Đã nhận đơn';
                        break;
                      case OrderStatus.preparing:
                        statusBgColor = Colors.purple.shade100;
                        statusTextColor = Colors.purple.shade900;
                        statusLabel = 'Đang pha chế';
                        break;
                      case OrderStatus.ready:
                        statusBgColor = Colors.green.shade100;
                        statusTextColor = Colors.green.shade900;
                        statusLabel = order.paymentId == null
                            ? 'Pha xong'
                            : 'Pha xong • Đã thu tiền';
                        break;
                      case OrderStatus.served:
                        statusBgColor = Colors.orange.shade100;
                        statusTextColor = Colors.orange.shade900;
                        statusLabel = 'Đã phục vụ • Chưa thu tiền';
                        break;
                      default:
                        statusBgColor = Colors.grey.shade100;
                        statusTextColor = Colors.black87;
                        statusLabel = order.status;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header của đơn
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      order.tableName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (order.orderType == OrderType.takeaway)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.brown.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Mang đi',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusTextColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Đặt lúc: ${timeFmt.format(order.createdAt)} • Người tạo: ${order.createdBy} (${order.createdByRole})',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                            const Divider(height: 16),

                            // Danh sách món
                            ...order.items.map((item) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.qty}x ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                          if (item.selectedOptions.isNotEmpty)
                                            Text(
                                              item.selectedOptions
                                                  .map((o) => o.choiceName)
                                                  .join(', '),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600),
                                            ),
                                          if (item.note != null &&
                                              item.note!.isNotEmpty)
                                            Text(
                                              'Ghi chú: ${item.note}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.red,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${currencyFmt.format(item.totalPrice)} đ',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 16),

                            // Tổng tiền & Nút điều khiển trạng thái
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Tổng: ${currencyFmt.format(order.total)} đ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // Đơn pending -> Nút Duyệt / Từ chối
                                    if (order.orderType == OrderType.takeaway &&
                                        order.paymentId == null &&
                                        [OrderStatus.ready, OrderStatus.served]
                                            .contains(order.orderStatus))
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: ElevatedButton.icon(
                                            onPressed: () => _checkoutTakeaway(
                                                context, order),
                                            icon: const Icon(Icons.payment),
                                            label: const Text('Thu tiền'),
                                          )),
                                    if (order.orderStatus ==
                                        OrderStatus.pending) ...[
                                      TextButton(
                                        onPressed: () => _promptCancelOrder(
                                            context, ref, order),
                                        child: const Text('Từ chối',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                      const SizedBox(width: 4),
                                      ElevatedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                  posDashboardViewModelProvider
                                                      .notifier)
                                              .approveOrder(
                                                  order.sessionId, order.id);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                        ),
                                        child: const Text('Duyệt đơn'),
                                      ),
                                    ],

                                    // Đơn confirmed -> Nút Bắt đầu pha chế
                                    if (order.orderStatus ==
                                        OrderStatus.confirmed)
                                      ElevatedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                  posDashboardViewModelProvider
                                                      .notifier)
                                              .updatePreparationStatus(
                                                order.sessionId,
                                                order.id,
                                                OrderStatus.preparing,
                                              );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                        ),
                                        child: const Text('Bắt đầu pha chế'),
                                      ),

                                    // Đơn preparing -> Nút Báo đã pha xong
                                    if (order.orderStatus ==
                                        OrderStatus.preparing)
                                      ElevatedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                  posDashboardViewModelProvider
                                                      .notifier)
                                              .updatePreparationStatus(
                                                order.sessionId,
                                                order.id,
                                                OrderStatus.ready,
                                              );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                        ),
                                        child:
                                            const Text('Pha xong -> Sẵn sàng'),
                                      ),

                                    // Đơn ready -> Nút Đã mang ra bàn
                                    if (order.orderStatus == OrderStatus.ready)
                                      ElevatedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                  posDashboardViewModelProvider
                                                      .notifier)
                                              .updatePreparationStatus(
                                                order.sessionId,
                                                order.id,
                                                OrderStatus.served,
                                              );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                        ),
                                        child: const Text('Đã phục vụ'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi tải hàng đợi: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _promptCancelOrder(
      BuildContext context, WidgetRef ref, OrderModel order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lý do từ chối đơn'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'VD: Hết nguyên liệu, khách đổi ý...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                ref
                    .read(posDashboardViewModelProvider.notifier)
                    .cancelOrder(order.sessionId, order.id, reason);
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );
  }

  void _checkoutTakeaway(BuildContext context, OrderModel order) {
    final preview = SessionModel(
        id: 'takeaway_orders',
        tableId: 'takeaway',
        tableName:
            'Mang đi #${order.id.substring(0, order.id.length < 6 ? order.id.length : 6)}',
        customerName: 'Khách mang đi',
        openedBy: order.createdBy,
        openedByRole: order.createdByRole,
        startedAt: order.createdAt,
        expiresAt: order.createdAt,
        subtotal: order.total);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PaymentCheckoutModal(
            session: preview, items: order.items, takeawayOrderId: order.id));
  }
}
