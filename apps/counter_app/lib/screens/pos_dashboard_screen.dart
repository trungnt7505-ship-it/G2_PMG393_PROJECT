import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import '../dialogs/universal_qr_scanner_dialog.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/pos_dashboard_viewmodel.dart';
import '../widgets/order_detail_panel.dart';
import '../widgets/order_queue_panel.dart';
import '../widgets/table_map_panel.dart';

/// Màn hình chính POS Dashboard được chia làm 3 cột dành cho Tablet / Desktop ngang:
/// - Cột 1 (Flex 3): Sơ đồ bàn tổng quan, màu sắc theo TableDisplayStatus, đồng hồ đếm ngược.
/// - Cột 2 (Flex 4): Hàng đợi pha chế (OrderQueuePanel) & tạo đơn Mang đi (Takeaway).
/// - Cột 3 (Flex 3): Chi tiết hóa đơn bàn được chọn, thông báo requests & nút thanh toán.
class PosDashboardScreen extends ConsumerStatefulWidget {
  const PosDashboardScreen({super.key});

  @override
  ConsumerState<PosDashboardScreen> createState() => _PosDashboardScreenState();
}

class _PosDashboardScreenState extends ConsumerState<PosDashboardScreen> {
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    // Bật timer định kỳ 2 giây quét cảnh báo đa bàn qua AlarmService
    _tickTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final activeSessions = ref.read(activeSessionsProvider).value ?? [];
      AlarmService.instance.onTickCheck(activeSessions);
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final user = currentUserAsync.value;
    final isManager = user?.userRole == UserRole.manager;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.coffee, color: Colors.white),
            const SizedBox(width: 10),
            const Text(
              'CAFE POS SYSTEM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 16),
            if (user != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${user.displayName} • ${user.role == 'manager' ? 'Quản lý' : 'Thu ngân'}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        actions: [
          // Nút Quét mã QR Đa Năng
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => UniversalQrScannerDialog(
                  onTableScanned: (tableId) {
                    ref
                        .read(posDashboardViewModelProvider.notifier)
                        .selectTable(tableId);
                  },
                ),
              );
            },
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            label: const Text('Quét QR', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),

          // Nút Admin / Quản lý
          if (isManager) ...[
            TextButton.icon(
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              label: const Text('Quản lý', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
          ],

          // Nút Đăng xuất
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xác nhận đăng xuất'),
                  content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi POS?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await ref.read(authViewModelProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Bố cục 3 cột chia tỷ lệ 3 : 4 : 3
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cột 1: Sơ đồ bàn (Flex 3)
              Expanded(
                flex: 3,
                child: TableMapPanel(),
              ),

              // Cột 2: Hàng đợi pha chế (Flex 4)
              Expanded(
                flex: 4,
                child: OrderQueuePanel(),
              ),

              // Cột 3: Chi tiết hóa đơn & Requests (Flex 3)
              Expanded(
                flex: 3,
                child: OrderDetailPanel(),
              ),
            ],
          );
        },
      ),
    );
  }
}

