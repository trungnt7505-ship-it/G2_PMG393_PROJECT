import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';

class PickupTimeDialog extends StatefulWidget {
  final DateTime initialPickupAt;
  final int maxAdvanceDays;

  const PickupTimeDialog({
    super.key,
    required this.initialPickupAt,
    required this.maxAdvanceDays,
  });

  @override
  State<PickupTimeDialog> createState() => _PickupTimeDialogState();
}

class _PickupTimeDialogState extends State<PickupTimeDialog> {
  late DateTime _pickupAt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pickupAt = widget.initialPickupAt;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEEE, dd/MM/yyyy · HH:mm');

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.takeout_dining, color: Color(0xFF5D4037)),
          SizedBox(width: 8),
          Expanded(child: Text('Đặt mang đi')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Chọn thời gian bạn sẽ đến quán nhận món:'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(DateFormat('dd/MM/yyyy').format(_pickupAt)),
          ),
          OutlinedButton.icon(
            onPressed: _chooseTime,
            icon: const Icon(Icons.schedule),
            label: Text(DateFormat('HH:mm').format(_pickupAt)),
          ),
          const SizedBox(height: 8),
          Text(
            'Hẹn nhận: ${formatter.format(_pickupAt)}',
            style: const TextStyle(
              color: Color(0xFF5D4037),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Đơn sẽ được nhân viên xác nhận và chuẩn bị để bạn đến lấy.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.check),
          label: const Text('Xác nhận giờ lấy'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5D4037),
          ),
        ),
      ],
    );
  }

  Future<void> _chooseDate() async {
    final now = ClockService.instance.serverNow;
    final latestDate = now.add(Duration(days: widget.maxAdvanceDays));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _pickupAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(latestDate.year, latestDate.month, latestDate.day),
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      _pickupAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        _pickupAt.hour,
        _pickupAt.minute,
      );
      _errorMessage = null;
    });
  }

  Future<void> _chooseTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickupAt),
    );
    if (selectedTime == null || !mounted) return;
    setState(() {
      _pickupAt = DateTime(
        _pickupAt.year,
        _pickupAt.month,
        _pickupAt.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      _errorMessage = null;
    });
  }

  void _confirm() {
    final now = ClockService.instance.serverNow;
    if (!_pickupAt.isAfter(now)) {
      setState(() {
        _errorMessage = 'Giờ nhận món phải ở trong tương lai.';
      });
      return;
    }
    if (_pickupAt.isAfter(now.add(Duration(days: widget.maxAdvanceDays)))) {
      setState(() {
        _errorMessage =
            'Chỉ có thể đặt nhận món trước tối đa ${widget.maxAdvanceDays} ngày.';
      });
      return;
    }
    Navigator.of(context).pop(_pickupAt);
  }
}
