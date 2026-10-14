import 'package:flutter/material.dart';
import '../constants/enums.dart';

/// Bảng màu chuẩn của toàn bộ hệ thống Cafe (Phụ trách: DƯƠNG BÙI).
class AppColors {
  // 6 màu chuẩn đại diện cho 6 trạng thái TableDisplayStatus
  /// Bàn trống, sẵn sàng đón khách (Xanh lá).
  static const Color statusFree = Color(0xFF2E7D32);

  /// Sắp có khách đặt hẹn tới trong vòng 30 phút (Tím).
  static const Color statusReservedSoon = Color(0xFF7B1FA2);

  /// Bàn đang có khách sử dụng bình thường (Xanh dương).
  static const Color statusUsing = Color(0xFF1976D2);

  /// Bàn sắp hết giờ <= 15 phút (Cam cảnh báo).
  static const Color statusExpiring = Color(0xFFF57C00);

  /// Bàn đã quá thời lượng quy định (Đỏ báo động).
  static const Color statusOvertime = Color(0xFFD32F2F);

  /// Bàn đang chờ nhân viên dọn dẹp (Xám).
  static const Color statusCleaning = Color(0xFF757575);

  // Bảng màu chủ đạo của ứng dụng Cafe
  static const Color primary = Color(0xFF6D4C41); // Nâu cafe
  static const Color primaryDark = Color(0xFF3E2723);
  static const Color primaryLight = Color(0xFFD7CCC8);
  static const Color accent = Color(0xFFFFB300); // Vàng caramel

  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  /// Lấy mã màu tương ứng với trạng thái hiển thị của bàn.
  static Color getStatusColor(TableDisplayStatus status) {
    switch (status) {
      case TableDisplayStatus.free:
        return statusFree;
      case TableDisplayStatus.reservedSoon:
        return statusReservedSoon;
      case TableDisplayStatus.using:
        return statusUsing;
      case TableDisplayStatus.expiring:
        return statusExpiring;
      case TableDisplayStatus.overtime:
        return statusOvertime;
      case TableDisplayStatus.cleaning:
        return statusCleaning;
    }
  }

  /// Lấy nhãn tiếng Việt tương ứng với trạng thái bàn.
  static String getStatusLabel(TableDisplayStatus status) {
    switch (status) {
      case TableDisplayStatus.free:
        return 'Bàn trống';
      case TableDisplayStatus.reservedSoon:
        return 'Sắp có khách';
      case TableDisplayStatus.using:
        return 'Đang dùng';
      case TableDisplayStatus.expiring:
        return 'Sắp hết giờ';
      case TableDisplayStatus.overtime:
        return 'Quá giờ';
      case TableDisplayStatus.cleaning:
        return 'Chờ dọn bàn';
    }
  }
}

