import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../repositories/customer_repository.dart';

/// Màn hình danh sách đơn Đặt bàn của tôi (MyReservationsScreen).
///
/// Cho phép:
/// 1. Xem lịch đặt bàn realtime từ [customerReservationsProvider].
/// 2. Hiển thị mã QR `cafe://preorder/{resId}` trực quan để xuất trình tại quầy check-in.
/// 3. Xem danh sách các món đặt trước (nếu có).
/// 4. Hủy đơn đặt bàn thông qua [ReservationService.cancelReservation] (tự động hoàn 5 slot).
class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider).value?.id;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập lại để xem lịch đặt bàn.')),
      );
    }

    final reservationsAsync = ref.watch(customerReservationsProvider(uid));
    final formatter = NumberFormat('#,###', 'vi_VN');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đặt bàn của tôi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sắp tới / Giữ chỗ'),
              Tab(text: 'Lịch sử'),
            ],
          ),
        ),
        body: reservationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không thể tải danh sách đặt bàn.\nKiểm tra kết nối mạng và quyền truy cập: $e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (items) {
            final upcoming = items.where((r) => r.status == 'confirmed').toList();
            final past = items.where((r) => r.status != 'confirmed').toList();

            return TabBarView(
              children: [
                // Tab 1: Sắp tới / Confirmed
                upcoming.isEmpty
                    ? _buildEmptyState('Bạn không có lịch đặt bàn nào sắp tới.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: upcoming.length,
                        itemBuilder: (context, idx) => _buildReservationCard(
                          context,
                          ref,
                          upcoming[idx],
                          isUpcoming: true,
                          formatter: formatter,
                        ),
                      ),

                // Tab 2: Lịch sử (checked_in, completed, cancelled, no_show)
                past.isEmpty
                    ? _buildEmptyState('Chưa có lịch sử đặt bàn nào.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: past.length,
                        itemBuilder: (context, idx) => _buildReservationCard(
                          context,
                          ref,
                          past[idx],
                          isUpcoming: false,
                          formatter: formatter,
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 64, color: Colors.black26),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    WidgetRef ref,
    ReservationModel res, {
    required bool isUpcoming,
    required NumberFormat formatter,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_restaurant, color: Color(0xFF5D4037)),
                    const SizedBox(width: 8),
                    Text(
                      res.tableName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ],
                ),
                _buildStatusTag(res.status),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  'Bắt đầu: ${DateFormat('dd/MM/yyyy · HH:mm').format(res.startTime)}',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  'Hạn giữ chỗ: ${DateFormat('HH:mm').format(res.holdUntil)}',
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.group_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  '${res.partySize} khách',
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ],
            ),

            // Danh sách món đặt trước (nếu có)
            if (res.hasPreOrder) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF9F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFECE5DE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Món đặt trước:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF5D4037)),
                        ),
                        Text(
                          'Tạm tính: ${formatter.format(res.preOrderTotal)} đ',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF5D4037)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...res.preOrderItems.map((item) => Text(
                          '• ${item.name} × ${item.qty}${item.selectedOptions.isNotEmpty ? " (${item.selectedOptions.map((o) => o.choiceName).join(", ")})" : ""}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        )),
                  ],
                ),
              ),
            ],

            // Mã QR check-in đặt trước dành cho đơn upcoming
            if (isUpcoming) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: QrImageView(
                      data: res.qrUrl,
                      version: QrVersions.auto,
                      size: 74,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QR Check-in đặt trước',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Đưa mã cho Quầy thu ngân khi tới quán để nhận bàn ngay.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: res.qrUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Đã sao chép nội dung mã QR!')),
                            );
                          },
                          child: const Text('Sao chép mã', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmCancel(context, ref, res.id),
                icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                label: const Text('Hủy đặt bàn này', style: TextStyle(color: Colors.red, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color color;
    String label;

    switch (status) {
      case 'confirmed':
        color = const Color(0xFF2E7D32);
        label = 'Đã xác nhận';
        break;
      case 'checked_in':
        color = const Color(0xFF1565C0);
        label = 'Đã nhận bàn';
        break;
      case 'completed':
        color = const Color(0xFF6A1B9A);
        label = 'Hoàn tất';
        break;
      case 'no_show':
        color = const Color(0xFFC62828);
        label = 'Quá giờ / No-show';
        break;
      case 'cancelled':
        color = Colors.grey.shade600;
        label = 'Đã hủy';
        break;
      default:
        color = Colors.black54;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String reservationId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đặt bàn'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy đơn đặt bàn này không? Khung giờ sẽ được giải phóng cho khách khác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hủy đặt bàn'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(customerRepositoryProvider).cancelReservation(reservationId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy đặt bàn thành công.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể hủy: $e')),
          );
        }
      }
    }
  }
}
