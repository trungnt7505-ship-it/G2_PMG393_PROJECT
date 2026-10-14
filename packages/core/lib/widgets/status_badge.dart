import 'package:flutter/material.dart';
import '../constants/enums.dart';
import '../theme/app_colors.dart';

/// Huy hiệu hiển thị trạng thái bàn hoặc trạng thái đơn hàng (Phụ trách: DƯƠNG BÙI).
class StatusBadge extends StatelessWidget {
  /// Trạng thái hiển thị của bàn.
  final TableDisplayStatus? tableStatus;

  /// Nhãn hiển thị tùy biến (nếu không dùng tableStatus).
  final String? label;

  /// Màu nền của huy hiệu (nếu không dùng tableStatus).
  final Color? color;

  const StatusBadge({
    super.key,
    this.tableStatus,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = tableStatus != null
        ? AppColors.getStatusColor(tableStatus!)
        : (color ?? AppColors.primary);

    final badgeText = tableStatus != null
        ? AppColors.getStatusLabel(tableStatus!)
        : (label ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 1.2),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
