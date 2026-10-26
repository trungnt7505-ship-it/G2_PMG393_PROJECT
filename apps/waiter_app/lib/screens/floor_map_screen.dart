import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import '../viewmodels/floor_map_viewmodel.dart';
import '../widgets/table_tile_widget.dart';
import '../widgets/table_action_sheet.dart';
import '../widgets/check_in_dialog.dart';
import '../widgets/switch_table_dialog.dart';

/// Màn hình Sơ đồ bàn [FloorMapScreen] tối ưu cho Nhân viên Phục vụ thao tác 1-tay (Phụ trách TRUNG).
class FloorMapScreen extends ConsumerWidget {
  const FloorMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floorState = ref.watch(floorMapViewModelProvider);
    final floorViewModel = ref.read(floorMapViewModelProvider.notifier);

    final tablesAsync = ref.watch(allTablesProvider);
    final activeSessionsAsync = ref.watch(activeSessionsProvider);
    final confirmedReservationsAsync = ref.watch(todayConfirmedReservationsProvider);
    final appConfigAsync = ref.watch(appConfigProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    final currentUser = currentUserAsync.value;
    final config = appConfigAsync.value ?? AppConfig.defaultConfig;
    final activeSessions = activeSessionsAsync.value ?? [];
    final confirmedReservations = confirmedReservationsAsync.value ?? [];

    // Kiểm tra và phát cảnh báo rung/âm thanh nếu có bàn chạm mốc 15', 5', 0'
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (activeSessions.isNotEmpty) {
        floorViewModel.checkAlarms(activeSessions, config);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: tablesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi tải dữ liệu bàn: $err')),
        data: (allTables) {
          if (allTables.isEmpty) {
            return const Center(child: Text('Chưa có dữ liệu bàn trong hệ thống.'));
          }

          // Lấy danh sách các Khu vực (Zone) độc nhất
          final zones = ['Tất cả', ...allTables.map((t) => t.zone).toSet()];

          // Lọc danh sách bàn theo Khu vực được chọn
          final filteredTables = floorState.selectedZone == 'Tất cả'
              ? allTables
              : allTables.where((t) => t.zone == floorState.selectedZone).toList();

          return Column(
            children: [
              // Thanh cuộn chọn Khu vực (Zone Filter Pills)
              Container(
                height: 50,
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: zones.length,
                  itemBuilder: (context, index) {
                    final zone = zones[index];
                    final isSelected = floorState.selectedZone == zone;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(zone),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => floorViewModel.setZone(zone),
                      ),
                    );
                  },
                ),
              ),

              // Thông báo tải/lỗi nếu có
              if (floorState.isLoading)
                const LinearProgressIndicator(color: AppColors.primary),
              if (floorState.errorMessage != null)
                Container(
                  color: Colors.red.shade100,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    floorState.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              // Lưới danh sách Bàn (Grid)
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredTables.length,
                  itemBuilder: (context, index) {
                    final table = filteredTables[index];

                    // Tìm phiên đang hoạt động của bàn
                    final activeSession = activeSessions.firstWhere(
                      (s) => s.tableId == table.id,
                      orElse: () => SessionModel(
                        id: '',
                        tableId: '',
                        tableName: '',
                        customerName: '',
                        openedBy: '',
                        openedByRole: '',
                        startedAt: DateTime.now(),
                        baseMinutes: 0,
                        extendedMinutes: 0,
                        expiresAt: DateTime.now(),
                        status: 'cancelled',
                        subtotal: 0,
                      ),
                    );

                    final hasSession = activeSession.id.isNotEmpty;

                    // Tìm lịch hẹn sắp tới của bàn
                    final nextRes = confirmedReservations.firstWhere(
                      (r) => r.tableId == table.id && r.status == 'confirmed',
                      orElse: () => ReservationModel(
                        id: '',
                        customerId: '',
                        customerName: '',
                        phone: '',
                        tableId: '',
                        tableName: '',
                        partySize: 0,
                        startTime: DateTime.now(),
                        endTime: DateTime.now(),
                        holdUntil: DateTime.now(),
                        status: 'cancelled',
                        createdAt: DateTime.now(),
                      ),
                    );

                    final hasRes = nextRes.id.isNotEmpty;

                    final sessionService = SessionService();
                    final displayStatus = sessionService.computeDisplayStatus(
                      table,
                      hasSession ? activeSession : null,
                      hasRes ? nextRes : null,
                      floorState.now,
                      config: config,
                    );

                    return TableTileWidget(
                      table: table,
                      activeSession: hasSession ? activeSession : null,
                      nextReservation: hasRes ? nextRes : null,
                      now: floorState.now,
                      config: config,
                      onTap: () {
                        _showTableActionSheet(
                          context,
                          ref,
                          table: table,
                          activeSession: hasSession ? activeSession : null,
                          nextReservation: hasRes ? nextRes : null,
                          displayStatus: displayStatus,
                          now: floorState.now,
                          config: config,
                          allTables: allTables,
                          confirmedReservations: confirmedReservations,
                          waiterUid: currentUser?.id ?? 'waiter_demo',
                        );
                      },
                      onRequestRelease: () {
                        if (hasSession) {
                          floorViewModel.sendReleaseTableRequest(
                            sessionId: activeSession.id,
                            tableId: table.id,
                            tableName: table.name,
                            createdBy: currentUser?.id ?? 'waiter_demo',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã gửi yêu cầu nhả bàn đến khách hàng!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Hiển thị TableActionSheet khi chạm vào 1 bàn
  void _showTableActionSheet(
    BuildContext context,
    WidgetRef ref, {
    required TableModel table,
    required SessionModel? activeSession,
    required ReservationModel? nextReservation,
    required TableDisplayStatus displayStatus,
    required DateTime now,
    required AppConfig config,
    required List<TableModel> allTables,
    required List<ReservationModel> confirmedReservations,
    required String waiterUid,
  }) {
    final floorViewModel = ref.read(floorMapViewModelProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return TableActionSheet(
          table: table,
          activeSession: activeSession,
          nextReservation: nextReservation,
          displayStatus: displayStatus,
          now: now,
          config: config,
          onOpenWalkIn: () async {
            final sessionId = await floorViewModel.openSessionForWalkIn(
              tableId: table.id,
              openedBy: waiterUid,
              openedByRole: 'waiter',
            );
            if (sessionId != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã mở bàn mới cho ${table.name}')),
              );
            }
          },
          onCheckInReservation: () {
            showDialog(
              context: context,
              builder: (dialogContext) {
                return CheckInDialog(
                  table: table,
                  confirmedReservations: confirmedReservations,
                  onConfirm: (res) async {
                    final sessionId = await floorViewModel.checkInReservation(
                      reservationId: res.id,
                      tableId: table.id,
                      openedBy: waiterUid,
                      openedByRole: 'waiter',
                      customerName: res.customerName,
                      customerId: res.customerId,
                    );
                    if (sessionId != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã check-in thành công cho ${res.customerName}')),
                      );
                    }
                  },
                );
              },
            );
          },
          onQuickOrder: () {
            if (activeSession != null) {
              context.push(
                '/quick-order?sessionId=${activeSession.id}&tableId=${table.id}&tableName=${Uri.encodeComponent(table.name)}',
              );
            }
          },
          onExtendSession: () async {
            if (activeSession != null) {
              final ok = await floorViewModel.extendSession(activeSession.id, waiterUid);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gia hạn bàn thành công +30 phút!')),
                );
              }
            }
          },
          onSwitchTable: () {
            if (activeSession != null) {
              final availableTables = allTables
                  .where((t) => t.id != table.id && t.status == 'available')
                  .toList();
              showDialog(
                context: context,
                builder: (dialogContext) {
                  return SwitchTableDialog(
                    currentTable: table,
                    availableTables: availableTables,
                    onConfirm: (targetTable) async {
                      final ok = await floorViewModel.switchTable(
                        sessionId: activeSession.id,
                        newTableId: targetTable.id,
                      );
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã chuyển phiên từ ${table.name} sang ${targetTable.name}')),
                        );
                      }
                    },
                  );
                },
              );
            }
          },
          onRequestRelease: () async {
            if (activeSession != null) {
              final ok = await floorViewModel.sendReleaseTableRequest(
                sessionId: activeSession.id,
                tableId: table.id,
                tableName: table.name,
                createdBy: waiterUid,
              );
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi thông báo yêu cầu nhả bàn!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          },
          onCancelSession: () async {
            if (activeSession != null) {
              final ok = await floorViewModel.cancelMistakenSession(activeSession.id);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã hủy phiên mở nhầm thành công.')),
                );
              }
            }
          },
          onMarkCleaned: () async {
            final ok = await floorViewModel.markTableCleaned(table.id);
            if (ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${table.name} đã sẵn sàng đón khách!')),
              );
            }
          },
        );
      },
    );
  }
}
