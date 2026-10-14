import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import '../viewmodels/pos_dashboard_viewmodel.dart';

/// Cột 1: Sơ đồ bàn tổng quan.
/// Hiển thị màu sắc theo 6 trạng thái TableDisplayStatus, đồng hồ đếm ngược
/// và cảnh báo nhấp nháy cho các bàn ở trạng thái `billing` (chờ thanh toán).
class TableMapPanel extends ConsumerWidget {
  const TableMapPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(allTablesProvider);
    final activeSessionsAsync = ref.watch(activeSessionsProvider);
    final todayReservationsAsync = ref.watch(todayConfirmedReservationsProvider);
    final dashboardState = ref.watch(posDashboardViewModelProvider);
    final sessionService = ref.watch(sessionServiceProvider);
    final now = ClockService.instance.serverNow;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Bộ lọc khu vực
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.table_restaurant, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Sơ đồ Bàn',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Tất cả', 'Tầng 1', 'Tầng 2'].map((zone) {
                    final isSelected = dashboardState.selectedZone == zone;
                    return ChoiceChip(
                      label: Text(zone),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) {
                        ref
                            .read(posDashboardViewModelProvider.notifier)
                            .filterZone(zone);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lưới bàn
          Expanded(
            child: tablesAsync.when(
              data: (tables) {
                final sessions = activeSessionsAsync.value ?? [];
                final reservations = todayReservationsAsync.value ?? [];

                final filteredTables = tables.where((t) {
                  if (dashboardState.selectedZone == 'Tất cả') return true;
                  return t.zone == dashboardState.selectedZone;
                }).toList();

                if (filteredTables.isEmpty) {
                  return const Center(child: Text('Không có bàn nào trong khu vực này.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredTables.length,
                  itemBuilder: (context, index) {
                    final table = filteredTables[index];
                    final activeSession = sessions.cast<SessionModel?>().firstWhere(
                          (s) => s?.tableId == table.id && s!.isActive,
                          orElse: () => null,
                        );

                    final nextRes = reservations.cast<ReservationModel?>().firstWhere(
                          (r) => r?.tableId == table.id,
                          orElse: () => null,
                        );

                    final displayStatus = sessionService.computeDisplayStatus(
                      table,
                      activeSession,
                      nextRes,
                      now,
                    );

                    final isSelected = dashboardState.selectedTableId == table.id;
                    final statusColor = AppColors.getStatusColor(displayStatus);
                    final isBilling = activeSession?.status == 'billing';

                    return InkWell(
                      onTap: () {
                        ref
                            .read(posDashboardViewModelProvider.notifier)
                            .selectTable(table.id);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? statusColor.withValues(alpha: 0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryDark : statusColor,
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  table.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    AppColors.getStatusLabel(displayStatus),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Cảnh báo khách chờ thanh toán (billing)
                            if (isBilling) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.payment, size: 14, color: Colors.red),
                                    SizedBox(width: 4),
                                    Text(
                                      'Chờ thanh toán',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Đồng hồ đếm ngược nếu bàn có phiên
                            if (activeSession != null) ...[
                              CountdownTimerWidget(
                                expiresAt: activeSession.expiresAt,
                                fontSize: 15,
                              ),
                            ] else ...[
                              Text(
                                '${table.capacity} chỗ ngồi • ${table.zone}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi tải bàn: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
