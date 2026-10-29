import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// Dialog cho phép Nhân viên Phục vụ hỗ trợ khách Check-in lịch đặt trước.
class CheckInDialog extends StatefulWidget {
  final TableModel table;
  final List<ReservationModel> confirmedReservations;
  final Function(ReservationModel selectedReservation) onConfirm;

  const CheckInDialog({
    super.key,
    required this.table,
    required this.confirmedReservations,
    required this.onConfirm,
  });

  @override
  State<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<CheckInDialog> {
  ReservationModel? _selectedReservation;

  @override
  Widget build(BuildContext context) {
    // Lọc các lịch hẹn đặt cho bàn này hoặc khớp với thời gian
    final tableReservations = widget.confirmedReservations
        .where((res) => res.tableId == widget.table.id)
        .toList();

    return AlertDialog(
      title: Text('Check-in lịch hẹn (${widget.table.name})'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn khách hàng đã đặt trước cho bàn này:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (tableReservations.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Không có lịch đặt trước nào gán trực tiếp cho bàn này.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...tableReservations.map((res) {
                return ListTile(
                  title: Text(res.customerName),
                  subtitle: Text(
                      'SĐT: ${res.phone} | Khách: ${res.partySize} người\nMón đặt trước: ${res.preOrderItems.length} món'),
                  selected: _selectedReservation == res,
                  leading: Icon(_selectedReservation == res
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  onTap: () {
                    setState(() {
                      _selectedReservation = res;
                    });
                  },
                );
              }),
            const Divider(height: 24),
            const Text(
              'Hoặc chọn từ danh sách tất cả đặt chỗ hôm nay:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReservationModel>(
              decoration: const InputDecoration(
                labelText: 'Danh sách đặt bàn hôm nay',
                border: OutlineInputBorder(),
              ),
              items: widget.confirmedReservations.map((res) {
                return DropdownMenuItem<ReservationModel>(
                  value: res,
                  child: Text(
                    '${res.customerName} - ${res.tableName} (${res.phone})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedReservation = val;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _selectedReservation == null
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onConfirm(_selectedReservation!);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Xác nhận Check-in'),
        ),
      ],
    );
  }
}
