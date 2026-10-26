import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';

/// Modal Bottom Sheet hiển thị danh sách thao tác xử lý cho Nhân viên Phục vụ khi chọn 1 bàn trên sơ đồ.
class TableActionSheet extends StatelessWidget {
  final TableModel table;
  final SessionModel? activeSession;
  final ReservationModel? nextReservation;
  final TableDisplayStatus displayStatus;
  final DateTime now;
  final AppConfig config;
  final VoidCallback onOpenWalkIn;
  final VoidCallback onCheckInReservation;
  final VoidCallback onQuickOrder;
  final VoidCallback onExtendSession;
  final VoidCallback onSwitchTable;
  final VoidCallback onRequestRelease;
  final VoidCallback onCancelSession;
  final VoidCallback onMarkCleaned;

  const TableActionSheet({
    super.key,
    required this.table,
    this.activeSession,
    this.nextReservation,
    required this.displayStatus,
    required this.now,
    required this.config,
    required this.onOpenWalkIn,
    required this.onCheckInReservation,
    required this.onQuickOrder,
    required this.onExtendSession,
    required this.onSwitchTable,
    required this.onRequestRelease,
    required this.onCancelSession,
    required this.onMarkCleaned,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final statusColor = AppColors.getStatusColor(displayStatus);
    final statusLabel = AppColors.getStatusLabel(displayStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh gạch chỉ dẫn kéo
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Thông tin tiêu đề Bàn & Trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      'Khu vực: ${table.zone} | Sức chứa: ${table.capacity} chỗ',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                StatusBadge(
                  label: statusLabel,
                  color: statusColor,
                ),
              ],
            ),
            const Divider(height: 24),

            // Thông tin chi tiết phiên nếu bàn đang sử dụng (occupied)
            if (activeSession != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Khách hàng:',
                            style: TextStyle(color: AppColors.textSecondary)),
                        Text(
                          activeSession!.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Giờ mở bàn:',
                            style: TextStyle(color: AppColors.textSecondary)),
                        Text(
                          DateFormat('HH:mm').format(activeSession!.startedAt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thời gian còn lại:',
                            style: TextStyle(color: AppColors.textSecondary)),
                        CountdownTimerWidget(
                          expiresAt: activeSession!.expiresAt,
                          fontSize: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính đơn:',
                            style: TextStyle(color: AppColors.textSecondary)),
                        Text(
                          currencyFormatter.format(activeSession!.subtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // DANH SÁCH THAO TÁC THEO TRẠNG THÁI BÀN
            const Text(
              'Thao tác cho phép:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // THƯỜNG TRƯỜNG BÀN TRỐNG (Available / ReservedSoon)
            if (displayStatus == TableDisplayStatus.free ||
                displayStatus == TableDisplayStatus.reservedSoon) ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.statusFree,
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
                title: const Text('Mở bàn khách vãng lai'),
                subtitle: const Text('Tạo phiên bàn mới cho khách chưa đặt trước'),
                onTap: () {
                  Navigator.pop(context);
                  onOpenWalkIn();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.statusReservedSoon,
                  child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                ),
                title: const Text('Check-in hộ khách đặt trước'),
                subtitle: const Text('Nhập mã đặt chỗ hoặc quét mã QR đặt món trước'),
                onTap: () {
                  Navigator.pop(context);
                  onCheckInReservation();
                },
              ),
            ],

            // TRƯỜNG HỢP BÀN ĐANG SỬ DỤNG (Using / Expiring / Overtime)
            if (displayStatus == TableDisplayStatus.using ||
                displayStatus == TableDisplayStatus.expiring ||
                displayStatus == TableDisplayStatus.overtime) ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.restaurant_menu_rounded, color: Colors.white),
                ),
                title: const Text('Đặt món hộ khách'),
                subtitle: const Text('Chọn nhanh các món và tùy chọn 1-tay siêu tốc'),
                onTap: () {
                  Navigator.pop(context);
                  onQuickOrder();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.more_time_rounded, color: Colors.white),
                ),
                title: const Text('Gia hạn hộ (+30 phút)'),
                subtitle: const Text('Cộng thêm thời lượng ngồi nếu không vướng lịch kế tiếp'),
                onTap: () {
                  Navigator.pop(context);
                  onExtendSession();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.swap_horiz_rounded, color: Colors.white),
                ),
                title: const Text('Chuyển sang bàn khác'),
                subtitle: const Text('Di chuyển phiên hiện tại sang một bàn trống'),
                onTap: () {
                  Navigator.pop(context);
                  onSwitchTable();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: displayStatus == TableDisplayStatus.overtime
                      ? AppColors.statusOvertime
                      : Colors.purple,
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.white),
                ),
                title: Text(
                  'Yêu cầu nhả bàn',
                  style: TextStyle(
                    color: displayStatus == TableDisplayStatus.overtime
                        ? AppColors.statusOvertime
                        : AppColors.textPrimary,
                    fontWeight: displayStatus == TableDisplayStatus.overtime
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: const Text('Gửi thông báo nhắc khách hết giờ hoặc sắp tới ca sau'),
                onTap: () {
                  Navigator.pop(context);
                  onRequestRelease();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.cancel_outlined, color: Colors.white),
                ),
                title: const Text('Hủy phiên mở nhầm'),
                subtitle: const Text('Đóng phiên và trả bàn về trạng thái trống'),
                onTap: () {
                  Navigator.pop(context);
                  onCancelSession();
                },
              ),
            ],

            // TRƯỜNG HỢP BÀN ĐANG CHỜ DỌN (Cleaning)
            if (displayStatus == TableDisplayStatus.cleaning) ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.statusFree,
                  child: Icon(Icons.cleaning_services_rounded, color: Colors.white),
                ),
                title: const Text('Đã dọn dẹp xong'),
                subtitle: const Text('Xác nhận bàn đã được dọn sạch và sẵn sàng đón khách mới'),
                onTap: () {
                  Navigator.pop(context);
                  onMarkCleaned();
                },
              ),
            ],

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
