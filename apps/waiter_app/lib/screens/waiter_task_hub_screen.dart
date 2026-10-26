import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';
import '../viewmodels/task_hub_viewmodel.dart';

/// Trung tâm Tác vụ [WaiterTaskHubScreen] của Nhân viên Phục vụ (Phụ trách TRUNG).
/// Gồm 3 Tab có Badge hiển thị số lượng realtime:
/// Tab 1: Duyệt đơn (pending)
/// Tab 2: Món chờ bưng (ready)
/// Tab 3: Yêu cầu từ bàn (requests)
class WaiterTaskHubScreen extends ConsumerWidget {
  const WaiterTaskHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingOrdersAsync = ref.watch(ordersByStatusesProvider(const [OrderStatus.pending]));
    final readyOrdersAsync = ref.watch(ordersByStatusesProvider(const [OrderStatus.ready]));
    final openRequestsAsync = ref.watch(openRequestsProvider);

    final pendingCount = pendingOrdersAsync.value?.length ?? 0;
    final readyCount = readyOrdersAsync.value?.length ?? 0;
    final requestsCount = openRequestsAsync.value?.length ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trung tâm Tác vụ'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Duyệt đơn'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 4),
                      Badge(
                        label: Text('$pendingCount'),
                        backgroundColor: Colors.red,
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Món chờ bưng'),
                    if (readyCount > 0) ...[
                      const SizedBox(width: 4),
                      Badge(
                        label: Text('$readyCount'),
                        backgroundColor: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Yêu cầu'),
                    if (requestsCount > 0) ...[
                      const SizedBox(width: 4),
                      Badge(
                        label: Text('$requestsCount'),
                        backgroundColor: Colors.purple,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Duyệt đơn pending từ khách tự đặt
            _PendingOrdersTab(pendingOrdersAsync: pendingOrdersAsync),

            // Tab 2: Món chờ bưng ready
            _ReadyOrdersTab(readyOrdersAsync: readyOrdersAsync),

            // Tab 3: Yêu cầu hỗ trợ từ bàn
            _OpenRequestsTab(openRequestsAsync: openRequestsAsync),
          ],
        ),
      ),
    );
  }
}

/// Tab 1: Danh sách Đơn pending chờ duyệt
class _PendingOrdersTab extends ConsumerWidget {
  final AsyncValue<List<OrderModel>> pendingOrdersAsync;

  const _PendingOrdersTab({required this.pendingOrdersAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final taskHubViewModel = ref.read(taskHubViewModelProvider.notifier);

    return pendingOrdersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Lỗi tải đơn: $err')),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                SizedBox(height: 8),
                Text('Không có đơn gọi món nào chờ duyệt!'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.tableName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm:ss').format(order.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...order.items.map((item) {
                      final optionsText = item.selectedOptions
                          .map((opt) => opt.choiceName)
                          .where((s) => s.isNotEmpty)
                          .join(', ');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              '${item.qty}x ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                            Expanded(
                              child: Text(
                                '${item.name} ${optionsText.isNotEmpty ? "($optionsText)" : ""} ${item.note != null && item.note!.isNotEmpty ? "[${item.note}]" : ""}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              currencyFormatter.format(item.totalPrice),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tổng tiền: ${currencyFormatter.format(order.total)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                _showCancelReasonDialog(
                                    context, ref, order.sessionId, order.id);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Từ chối'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final ok = await taskHubViewModel.approveOrder(
                                    order.sessionId, order.id);
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Đã duyệt đơn cho ${order.tableName}')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Duyệt đơn'),
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
    );
  }

  void _showCancelReasonDialog(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String orderId,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Từ chối đơn hàng'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Nhập lý do từ chối (Hết món, v.v.)...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = controller.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(context);

                final ok = await ref
                    .read(taskHubViewModelProvider.notifier)
                    .cancelOrder(sessionId, orderId, reason: reason);

                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã từ chối đơn hàng.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xác nhận từ chối'),
            ),
          ],
        );
      },
    );
  }
}

/// Tab 2: Danh sách Món đã pha chế xong (Ready) chờ bưng ra bàn
class _ReadyOrdersTab extends ConsumerWidget {
  final AsyncValue<List<OrderModel>> readyOrdersAsync;

  const _ReadyOrdersTab({required this.readyOrdersAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskHubViewModel = ref.read(taskHubViewModelProvider.notifier);

    return readyOrdersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_food_beverage_outlined,
                    size: 48, color: Colors.amber),
                SizedBox(height: 8),
                Text('Không có món nào đang chờ bưng ra bàn!'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.restaurant, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              order.tableName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SẴN SÀNG',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...order.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${item.qty}x ${item.name}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await taskHubViewModel.markOrderServed(
                            order.sessionId,
                            order.id,
                          );
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Đã xác nhận mang món ra ${order.tableName}'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('ĐÃ MANG RA BÀN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Tab 3: Yêu cầu từ bàn (Call Waiter, Request Bill, Release Table, Early Release)
class _OpenRequestsTab extends ConsumerWidget {
  final AsyncValue<List<RequestModel>> openRequestsAsync;

  const _OpenRequestsTab({required this.openRequestsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskHubViewModel = ref.read(taskHubViewModelProvider.notifier);

    return openRequestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Lỗi tải yêu cầu: $err')),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined,
                    size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Hiện không có yêu cầu nào cần xử lý.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];

            String titleLabel = 'Yêu cầu từ bàn';
            Color tagColor = Colors.blue;
            IconData iconData = Icons.notifications;

            switch (req.requestType) {
              case RequestType.call_waiter:
                titleLabel = 'GỌI PHỤC VỤ';
                tagColor = Colors.orange;
                iconData = Icons.person_pin;
                break;
              case RequestType.request_bill:
                titleLabel = 'YÊU CẦU TÍNH TIỀN';
                tagColor = Colors.green;
                iconData = Icons.receipt_long;
                break;
              case RequestType.release_table:
                titleLabel = 'YÊU CẦU NHẢ BÀN';
                tagColor = Colors.red;
                iconData = Icons.warning;
                break;
              case RequestType.early_release:
                titleLabel = 'TRẢ BÀN SỚM (+20 ĐIỂM)';
                tagColor = Colors.purple;
                iconData = Icons.star;
                break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: tagColor,
                      child: Icon(iconData, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.tableName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            titleLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tagColor,
                              fontSize: 12,
                            ),
                          ),
                          if (req.message.isNotEmpty)
                            Text(
                              req.message,
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(
                            DateFormat('HH:mm:ss').format(req.createdAt),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final ok = await taskHubViewModel.resolveRequest(req.id);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã xử lý xong yêu cầu!')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Đã xong'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
