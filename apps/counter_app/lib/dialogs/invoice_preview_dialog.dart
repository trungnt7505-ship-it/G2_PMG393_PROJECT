import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';

/// Xem hóa đơn đã thanh toán trên màn hình laptop.
class InvoicePreviewDialog extends StatelessWidget {
  final PaymentModel payment;
  final List<OrderItemModel> items;

  const InvoicePreviewDialog({
    super.key,
    required this.payment,
    this.items = const [],
  });

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'vi_VN');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề biên lai
            const Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long, color: AppColors.primary, size: 40),
                  SizedBox(height: 6),
                  Text(
                    'CAFE SYSTEM - HÓA ĐƠN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Phiếu thanh toán kiêm tích điểm',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1.5, height: 28),

            // Thông tin chung
            _buildRow('Mã hóa đơn:', payment.id),
            _buildRow('Bàn phục vụ:', payment.tableName),
            _buildRow('Thu ngân:', payment.cashierId),
            _buildRow('Thời gian:', dateFmt.format(payment.paidAt)),
            _buildRow(
              'Phương thức:',
              payment.method == 'cash'
                  ? 'Tiền mặt'
                  : payment.method == 'qr'
                      ? 'Chuyển khoản QR'
                      : 'Thẻ ngân hàng',
            ),
            const Divider(thickness: 1, height: 20),

            // Danh sách món nếu có truyền vào
            if (items.isNotEmpty) ...[
              const Text(
                'Chi tiết món:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.qty}x ${item.name}',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${currencyFmt.format(item.totalPrice)} đ',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(thickness: 1, height: 20),
            ],

            // Chi tiết tiền
            _buildRow('Tạm tính:', '${currencyFmt.format(payment.subtotal)} đ'),
            if (payment.discount > 0)
              _buildRow(
                'Giảm giá (${payment.pointsUsed} điểm):',
                '-${currencyFmt.format(payment.discount)} đ',
                valueColor: Colors.red,
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TỔNG CỘNG:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${currencyFmt.format(payment.total)} đ',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 1, height: 20),

            // Thông tin tích điểm
            if (payment.customerId != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  children: [
                    _buildRow(
                        'Điểm tích lũy mới:', '+${payment.pointsEarned} điểm'),
                    if (payment.bonusPoints > 0)
                      _buildRow(
                        'Điểm thưởng ưu đãi:',
                        '+${payment.bonusPoints} điểm',
                        valueColor: Colors.green.shade800,
                      ),
                    const Divider(height: 10),
                    _buildRow(
                      'Tổng điểm nhận:',
                      '+${payment.totalPointsReceived} điểm',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Nút bấm
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
