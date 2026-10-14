import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';

/// Màn hình Quản lý / Quản trị viên (ManagerAdminScreen):
/// - Bật/tắt món ăn/nước uống còn hàng (`available`).
/// - Chỉnh sửa thông số hệ thống `config/app`.
/// - Nút chạy `SeedService` nạp dữ liệu mẫu ban đầu.
/// - Thống kê doanh thu, số phiên và số lượt khách bỏ bàn (no-show) trong ngày.
class ManagerAdminScreen extends ConsumerStatefulWidget {
  const ManagerAdminScreen({super.key});

  @override
  ConsumerState<ManagerAdminScreen> createState() => _ManagerAdminScreenState();
}

class _ManagerAdminScreenState extends ConsumerState<ManagerAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSeeding = false;
  String? _seedMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runSeedData() async {
    setState(() {
      _isSeeding = true;
      _seedMessage = 'Đang khởi tạo 12 bàn mẫu, 10 món nước và cấu hình...';
    });

    try {
      final seedService = ref.read(seedServiceProvider);
      await seedService.seedInitialDataIfEmpty();
      if (!mounted) return;
      setState(() {
        _isSeeding = false;
        _seedMessage = 'Khởi tạo dữ liệu mẫu thành công!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSeeding = false;
        _seedMessage = 'Lỗi Seed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QUẢN TRỊ VIÊN & CẤU HÌNH HỆ THỐNG'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Thực đơn món'),
            Tab(icon: Icon(Icons.settings), text: 'Cấu hình App'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Thống kê & Dữ liệu mẫu'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMenuManagementTab(),
          _buildConfigTab(),
          _buildStatsAndSeedTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: BẬT / TẮT MÓN THỰC ĐƠN
  // ==========================================
  Widget _buildMenuManagementTab() {
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final currencyFmt = NumberFormat('#,###', 'vi_VN');

    return menuItemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Chưa có món nào trên hệ thống.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: item.available ? Colors.brown.shade100 : Colors.grey.shade300,
                child: Icon(
                  Icons.local_cafe,
                  color: item.available ? AppColors.primary : Colors.grey,
                ),
              ),
              title: Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: item.available ? null : TextDecoration.lineThrough,
                  color: item.available ? Colors.black87 : Colors.grey,
                ),
              ),
              subtitle: Text(
                '${item.category} • ${currencyFmt.format(item.price)} đ',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.available ? 'Còn món' : 'Hết hàng',
                    style: TextStyle(
                      color: item.available ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: item.available,
                    activeThumbColor: Colors.green,
                    onChanged: (val) async {
                      await ref
                          .read(orderServiceProvider)
                          .toggleMenuItemAvailability(item.id, val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải thực đơn: $e')),
    );
  }

  // ==========================================
  // TAB 2: CẤU HÌNH HỆ THỐNG
  // ==========================================
  Widget _buildConfigTab() {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      data: (config) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tham số vận hành quy định trong config/app',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildConfigItem('Thời lượng phiên tiêu chuẩn:', '${config.sessionMinutes} phút'),
                  _buildConfigItem('Mỗi lần gia hạn cộng thêm:', '${config.extendStepMinutes} phút'),
                  _buildConfigItem('Các mốc cảnh báo hết giờ:', '${config.warnMinutes.join(', ')} phút'),
                  _buildConfigItem('Hạn chót giữ chỗ sau giờ hẹn:', '${config.reservationHoldMinutes} phút'),
                  _buildConfigItem('Khoảng đệm dọn bàn giữa 2 phiên:', '${config.bufferMinutes} phút'),
                  _buildConfigItem('Cho phép check-in sớm tối đa:', '${config.checkInEarlyMinutes} phút'),
                  _buildConfigItem('Tỷ lệ tích lũy điểm:', '${config.pointEarnVnd} VND = 1 điểm'),
                  _buildConfigItem('Tỷ lệ đổi điểm giảm giá:', '1 điểm = ${config.pointRedeemVnd} VND'),
                  _buildConfigItem('Giảm giá tối đa bằng điểm:', '${config.maxRedeemPercent}%'),
                  _buildConfigItem('Thưởng trả bàn sớm (>=30p):', '+${config.earlyReleaseBonusPoints} điểm'),
                  _buildConfigItem('Thưởng đặt món trước:', '+${config.preOrderBonusPoints} điểm'),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải cấu hình: $e')),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: THỐNG KÊ & SEED DỮ LIỆU
  // ==========================================
  Widget _buildStatsAndSeedTab() {
    final currencyFmt = NumberFormat('#,###', 'vi_VN');
    final paymentsAsync = ref.watch(todayPaymentsProvider);
    final noShowsAsync = ref.watch(todayNoShowsProvider);

    final payments = paymentsAsync.value ?? [];
    final totalRevenue = payments.fold<int>(0, (sum, p) => sum + p.total);
    final invoiceCount = payments.length;

    final noShows = noShowsAsync.value ?? [];
    final noShowCount = noShows.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thống kê trong ngày
              const Text(
                'Thống kê vận hành trong ngày hôm nay',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Tổng doanh thu hôm nay',
                      '${currencyFmt.format(totalRevenue)} đ',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Số lượt hóa đơn',
                      '$invoiceCount đơn',
                      Icons.receipt,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Số lượt khách bỏ bàn (No-show)',
                '$noShowCount lượt',
                Icons.event_busy,
                Colors.red,
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Nút khởi tạo dữ liệu mẫu Seed Data
              const Text(
                'Khởi tạo Dữ liệu mẫu (Seed Initial Data)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tự động kiểm tra và nạp sẵn 12 bàn mẫu (Tầng 1 & Tầng 2), 10 món nước/bánh kèm Topping & Size, và cấu hình mặc định vào Cloud Firestore.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSeeding ? null : _runSeedData,
                icon: _isSeeding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _isSeeding ? 'Đang khởi tạo...' : 'Chạy Seed Data',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_seedMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _seedMessage!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _seedMessage!.contains('Lỗi') ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 24,
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
