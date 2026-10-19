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
  int _panelIndex = 0;

  @override
  void initState() {
    super.initState();
    // Bật timer định kỳ 2 giây quét cảnh báo đa bàn qua AlarmService
    _tickTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final activeSessions = ref.read(activeSessionsProvider).valueOrNull ?? [];
      final config =
          ref.read(appConfigProvider).valueOrNull ?? AppConfig.defaultConfig;
      AlarmService.instance.onTickCheck(activeSessions, config: config);
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
    final user = currentUserAsync.valueOrNull;
    final isManager = user?.userRole == UserRole.manager;
    final compact = MediaQuery.sizeOf(context).width < 900;
    final busy = ref
        .watch(posDashboardViewModelProvider.select((s) => s.isActionLoading));
    ref.listen(posDashboardViewModelProvider, (previous, next) {
      if (next.actionMessage != null &&
          next.actionMessage != previous?.actionMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.actionMessage!)));
      }
      if (next.selectedTableId != previous?.selectedTableId &&
          next.selectedTableId != null &&
          MediaQuery.sizeOf(context).width < 1200) {
        setState(() => _panelIndex = 2);
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.coffee, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(
                child: Text(
              compact ? 'CAFE POS' : 'CAFE POS SYSTEM',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            )),
            const SizedBox(width: 16),
            if (user != null && !compact)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                    width: 200,
                    child: Text(
                      '${user.displayName} • ${user.role == 'manager' ? 'Quản lý' : 'Thu ngân'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    )),
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
            label: Text(compact ? '' : 'Quét QR',
                style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),

          // Nút Admin / Quản lý
          if (isManager) ...[
            TextButton.icon(
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              label: Text(compact ? '' : 'Quản lý',
                  style: const TextStyle(color: Colors.white)),
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
                  content:
                      const Text('Bạn có chắc chắn muốn đăng xuất khỏi POS?'),
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
      body: Stack(children: [
        AbsorbPointer(
            absorbing: busy,
            child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 1200) {
                return const Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 28, child: TableMapPanel()),
                      Expanded(flex: 40, child: OrderQueuePanel()),
                      Expanded(flex: 32, child: OrderDetailPanel()),
                    ]);
              }
              return Column(children: [
                Expanded(
                    child: IndexedStack(index: _panelIndex, children: const [
                  TableMapPanel(),
                  OrderQueuePanel(),
                  OrderDetailPanel(),
                ])),
                NavigationBar(
                    selectedIndex: _panelIndex,
                    onDestinationSelected: (index) =>
                        setState(() => _panelIndex = index),
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.table_restaurant),
                          label: 'Sơ đồ bàn'),
                      NavigationDestination(
                          icon: Icon(Icons.soup_kitchen), label: 'Pha chế'),
                      NavigationDestination(
                          icon: Icon(Icons.receipt_long),
                          label: 'Chi tiết bàn'),
                    ]),
              ]);
            })),
        if (busy)
          const Align(
              alignment: Alignment.topCenter, child: LinearProgressIndicator()),
      ]),
    );
  }
}
