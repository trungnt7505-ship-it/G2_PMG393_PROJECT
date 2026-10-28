import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';

import '../../repositories/customer_repository.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/active_session_banner.dart';
import '../../widgets/member_qr_dialog.dart';
import '../../widgets/item_options_dialog.dart';
import '../reservation/reservation_booking_screen.dart';
import '../reservation/my_reservations_screen.dart';
import '../scanner/table_qr_scanner_screen.dart';
import '../history/points_and_history_screen.dart';

/// Màn hình chính của Khách hàng (CustomerHomeScreen).
///
/// Hiển thị:
/// 1. Thông tin thẻ thành viên & điểm tích lũy & QR thành viên.
/// 2. Banner phiên bàn đang dùng nếu khách đang có phiên hoạt động (`activeSession`).
/// 3. Lối tắt nhanh: Đặt bàn trước, Quét QR check-in bàn, Lịch sử đặt chỗ, Lịch sử điểm.
/// 4. Thực đơn trực tiếp (Live Menu) có bộ lọc danh mục và chi tiết tùy chọn món.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final config = ref.watch(appConfigProvider).value ?? AppConfig.defaultConfig;
    final activeSessionAsync = ref.watch(activeCustomerSessionProvider);
    final filteredMenuAsync = ref.watch(filteredMenuItemsProvider);
    final homeState = ref.watch(homeViewModelProvider);
    final homeVm = ref.read(homeViewModelProvider.notifier);
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.coffee, color: Color(0xFF5D4037)),
            SizedBox(width: 8),
            Text(
              'G2 Cafe',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Lịch sử tích điểm & hóa đơn',
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PointsAndHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Đặt bàn của tôi',
            icon: const Icon(Icons.event_note),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MyReservationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Banner phiên đang dùng (nếu có)
          activeSessionAsync.when(
            data: (session) => session != null
                ? ActiveSessionBanner(session: session, config: config)
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 2. Thẻ thành viên VIP & Điểm tích lũy
          if (user != null) _buildMemberCard(context, user, formatter),

          const SizedBox(height: 16),

          // 3. Các nút tác vụ nhanh (Quick Actions)
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.event_available,
                  title: 'Đặt bàn trước',
                  subtitle: 'Giữ chỗ & chọn món',
                  color: const Color(0xFF4E342E),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReservationBookingScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.qr_code_scanner,
                  title: 'Check-in bàn',
                  subtitle: 'Quét mã nhận chỗ',
                  color: const Color(0xFF2E7D32),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TableQrScannerScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4. Tiêu đề thực đơn và thanh tìm kiếm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Thực đơn quán',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723),
                ),
              ),
              Text(
                'Giá đã gồm thuế',
                style: TextStyle(fontSize: 12, color: Colors.brown.shade300),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Bar
          TextField(
            onChanged: homeVm.updateSearchQuery,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm cà phê, trà, bánh ngọt...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: homeState.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => homeVm.updateSearchQuery(''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'Tất cả',
                'Cà phê',
                'Trà trái cây',
                'Bánh ngọt',
                'Đá xay',
                'Nước ép',
              ].map((category) {
                final isSelected = homeState.selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD7CCC8),
                    checkmarkColor: const Color(0xFF5D4037),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF3E2723) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => homeVm.selectCategory(category),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Danh sách món thực đơn
          filteredMenuAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.black26),
                      SizedBox(height: 8),
                      Text(
                        'Không tìm thấy món phù hợp.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFEBE5DF)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEBE9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.coffee, color: Color(0xFF6D4C41), size: 24),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          if (!item.available)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Tạm hết',
                                style: TextStyle(color: Colors.black45, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            item.category,
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatter.format(item.price)} đ',
                            style: const TextStyle(
                              color: Color(0xFF5D4037),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF5D4037), size: 30),
                        tooltip: 'Xem tùy chọn món',
                        onPressed: item.available
                            ? () {
                                showDialog<void>(
                                  context: context,
                                  builder: (_) => ItemOptionsDialog(
                                    item: item,
                                    onConfirm: (orderItem) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đã chọn ${orderItem.name} (${orderItem.qty})'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }
                            : null,
                      ),
                      onTap: item.available
                          ? () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => ItemOptionsDialog(
                                  item: item,
                                  onConfirm: (orderItem) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Đã chọn ${orderItem.name} (${orderItem.qty})'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          : null,
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(child: Text('Lỗi tải thực đơn: $e')),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    UserModel user,
    NumberFormat formatter,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE5DE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFEFEBE9),
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName.substring(0, 1).toUpperCase()
                      : 'K',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty ? user.displayName : 'Khách hàng',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.phone.isNotEmpty ? user.phone : user.email,
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE0B2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Color(0xFFE65100), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${formatter.format(user.points)} điểm',
                      style: const TextStyle(
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => MemberQrDialog(user: user),
                  );
                },
                icon: const Icon(Icons.qr_code, size: 18),
                label: const Text('Mã QR tích điểm'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5D4037),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PointsAndHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Xem lịch sử điểm'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5D4037),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5D4037)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(customerRepositoryProvider).signOut();
      ref.invalidate(currentUserProvider);
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECE5DE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
