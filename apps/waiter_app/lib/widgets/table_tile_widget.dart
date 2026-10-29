import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// Ô hiển thị thông tin Bàn trên Sơ đồ [FloorMapScreen] (Phụ trách: TRUNG).
/// Hiển thị tên bàn, sức chứa, khu vực, màu sắc theo [TableDisplayStatus],
/// đồng hồ đếm ngược thời lượng phiên và nút "Yêu cầu nhả bàn" khi quá giờ.
class TableTileWidget extends StatelessWidget {
  final TableModel table;
  final SessionModel? activeSession;
  final ReservationModel? nextReservation;
  final DateTime now;
  final AppConfig config;
  final VoidCallback onTap;
  final VoidCallback? onRequestRelease;

  const TableTileWidget({
    super.key,
    required this.table,
    this.activeSession,
    this.nextReservation,
    required this.now,
    this.config = AppConfig.defaultConfig,
    required this.onTap,
    this.onRequestRelease,
  });

  @override
  Widget build(BuildContext context) {
    final sessionService = SessionService();
    final displayStatus = sessionService.computeDisplayStatus(
      table,
      activeSession,
      nextReservation,
      now,
      config: config,
    );

    final statusColor = AppColors.getStatusColor(displayStatus);
    final statusLabel = AppColors.getStatusLabel(displayStatus);

    final isOvertime = displayStatus == TableDisplayStatus.overtime;
    final isExpiring = displayStatus == TableDisplayStatus.expiring;

    return Card(
      elevation: isOvertime ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOvertime
              ? AppColors.statusOvertime
              : isExpiring
                  ? AppColors.statusExpiring
                  : Colors.transparent,
          width: isOvertime ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: statusColor.withValues(alpha: 0.08),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng tiêu đề: Tên bàn + Huy hiệu trạng thái
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      table.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Thông tin phụ: Khu vực & Sức chứa
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Expanded(
                      child: Text(
                    table.zone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  )),
                  const Icon(Icons.people_outline,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    '${table.capacity} chỗ',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),

              // Nội dung phiên hoặc đồng hồ đếm ngược
              if (activeSession != null) ...[
                Row(
                  children: [
                    Icon(
                      isOvertime
                          ? Icons.warning_amber_rounded
                          : Icons.access_time_rounded,
                      size: 16,
                      color: isOvertime
                          ? AppColors.statusOvertime
                          : isExpiring
                              ? AppColors.statusExpiring
                              : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: CountdownTimerWidget(
                        expiresAt: activeSession!.expiresAt,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  activeSession!.customerName,
                  style: const TextStyle(
                      fontSize: 11, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (nextReservation != null) ...[
                Row(
                  children: [
                    const Icon(Icons.event_seat_outlined,
                        size: 14, color: AppColors.statusReservedSoon),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Đặt hẹn: ${nextReservation!.customerName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.statusReservedSoon,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Sẵn sàng đón khách',
                  style: TextStyle(fontSize: 11, color: AppColors.statusFree),
                ),
              ],

              // Nút bấm "Yêu cầu nhả bàn" hiển thị khi bàn ở trạng thái quá giờ (Overtime)
              if (isOvertime) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton.icon(
                    key: const Key('release_table_button'),
                    onPressed: onRequestRelease,
                    icon: const Icon(Icons.notifications_active, size: 14),
                    label: const Text(
                      'Yêu cầu nhả bàn',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusOvertime,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
