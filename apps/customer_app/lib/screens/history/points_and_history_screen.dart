import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';

import '../../repositories/customer_repository.dart';

/// Màn hình Lịch sử tích điểm và Hóa đơn thanh toán của khách hàng (PointsAndHistoryScreen).
///
/// Tuân thủ quy định:
/// 1. Sử dụng [customerPointTxProvider] và [customerPaymentsProvider] từ CustomerRepository.
/// 2. Không truy vấn Firestore trực tiếp trong UI.
/// 3. Được bảo vệ bởi Security Rules: chỉ hiển thị dữ liệu của chính người dùng (`isOwner` / `customerId == uid`).
class PointsAndHistoryScreen extends ConsumerWidget {
  const PointsAndHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final pointTxAsync = ref.watch(customerPointTxProvider);
    final paymentsAsync = ref.watch(customerPaymentsProvider);
    final config = ref.watch(appConfigProvider).value ?? AppConfig.defaultConfig;
    final formatter = NumberFormat('#,###', 'vi_VN');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Điểm thưởng & Hóa đơn'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lịch sử điểm'),
              Tab(text: 'Hóa đơn đã thanh toán'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Lịch sử điểm tích lũy
            _buildPointHistoryTab(context, user, config, pointTxAsync, formatter),

            // Tab 2: Lịch sử hóa đơn thanh toán
            _buildPaymentHistoryTab(context, ref, paymentsAsync, formatter),
          ],
        ),
      ),
    );
  }

  Widget _buildPointHistoryTab(
    BuildContext context,
    UserModel? user,
    AppConfig config,
    AsyncValue<List<PointTxModel>> pointTxAsync,
    NumberFormat formatter,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Thẻ tổng quan điểm tích lũy
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3E2723), Color(0xFF5D4037)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x203E2723),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SỐ ĐIỂM HIỆN CÓ',
                style: TextStyle(
                  color: Color(0xFFD7CCC8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatter.format(user?.points ?? 0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'điểm',
                    style: TextStyle(color: Color(0xFFFFCC80), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                '• ${formatter.format(config.pointEarnVnd)}đ chi tiêu = 1 điểm tích lũy\n'
                '• 1 điểm = ${formatter.format(config.pointRedeemVnd)}đ giảm giá khi thanh toán (tối đa ${config.maxRedeemPercent}% bill)\n'
                '• Thưởng ${config.earlyReleaseBonusPoints} điểm khi trả bàn sớm, ${config.preOrderBonusPoints} điểm khi đặt món trước.',
                style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Biến động điểm gần đây',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3E2723)),
        ),
        const SizedBox(height: 10),

        pointTxAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Text('Lỗi tải biến động điểm: $e')),
          data: (transactions) {
            if (transactions.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Chưa có giao dịch biến động điểm nào.', style: TextStyle(color: Colors.black45)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final tx = transactions[idx];
                final isPositive = tx.points >= 0;
                final info = _formatPointTxType(tx.type);

                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFECE5DE)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: isPositive ? Colors.green : Colors.red,
                        size: 22,
                      ),
                    ),
                    title: Text(info.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy · HH:mm').format(tx.at),
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                    trailing: Text(
                      '${isPositive ? "+" : ""}${tx.points} điểm',
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF2E7D32) : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPaymentHistoryTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<PaymentModel>> paymentsAsync,
    NumberFormat formatter,
  ) {
    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải hóa đơn: $e')),
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_outlined, size: 54, color: Colors.black26),
                SizedBox(height: 12),
                Text('Bạn chưa có hóa đơn thanh toán nào.', style: TextStyle(color: Colors.black45)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final p = payments[idx];
            return Card(
              elevation: 0.8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hóa đơn #${p.id.length > 6 ? p.id.substring(p.id.length - 6) : p.id}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Đã thanh toán',
                            style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.table_bar, size: 16, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(p.tableName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        const Icon(Icons.schedule, size: 16, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(p.paidAt),
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                        Text('${formatter.format(p.subtotal)} đ', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    if (p.discount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đổi ${p.pointsUsed} điểm:', style: const TextStyle(fontSize: 13, color: Colors.green)),
                          Text('-${formatter.format(p.discount)} đ', style: const TextStyle(fontSize: 13, color: Colors.green)),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thực trả:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '${formatter.format(p.total)} đ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Phương thức: ${_formatMethod(p.method)}',
                          style: const TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                        if (p.pointsEarned > 0 || p.bonusPoints > 0)
                          Text(
                            '+${p.pointsEarned + p.bonusPoints} điểm thưởng',
                            style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showInvoiceItemsDialog(context, ref, p.id, formatter),
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('Xem danh sách món', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5D4037),
                        side: const BorderSide(color: Color(0xFFD7CCC8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
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

  void _showInvoiceItemsDialog(
    BuildContext context,
    WidgetRef ref,
    String paymentId,
    NumberFormat formatter,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chi tiết món hóa đơn'),
        content: FutureBuilder<List<OrderItemModel>>(
          future: ref.read(customerRepositoryProvider).getPaymentItems(paymentId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Không thể tải món: ${snapshot.error}');
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Text('Không có dữ liệu món trong bản snapshot.');
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final i = items[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${i.name} × ${i.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: i.selectedOptions.isNotEmpty
                        ? Text(i.selectedOptions.map((o) => o.choiceName).join(', '), style: const TextStyle(fontSize: 11))
                        : null,
                    trailing: Text('${formatter.format(i.totalPrice)} đ', style: const TextStyle(fontSize: 13)),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  _PointTxDisplayInfo _formatPointTxType(String type) {
    switch (type) {
      case 'earn':
        return _PointTxDisplayInfo('Tích điểm từ hóa đơn');
      case 'redeem':
        return _PointTxDisplayInfo('Đổi điểm giảm giá');
      case 'bonus_early_release':
        return _PointTxDisplayInfo('Thưởng trả bàn sớm');
      case 'bonus_preorder':
        return _PointTxDisplayInfo('Thưởng đặt món trước');
      default:
        return _PointTxDisplayInfo('Giao dịch điểm: $type');
    }
  }

  String _formatMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'qr':
        return 'Chuyển khoản QR';
      case 'card':
        return 'Thẻ ngân hàng';
      default:
        return method;
    }
  }
}

class _PointTxDisplayInfo {
  final String title;
  _PointTxDisplayInfo(this.title);
}
