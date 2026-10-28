import 'dart:async';
import 'package:flutter/material.dart';
import '../services/clock_service.dart';
import '../theme/app_colors.dart';

/// Widget đồng hồ đếm ngược thời lượng phiên dùng bàn (Phụ trách: DƯƠNG BÙI).
/// Hiển thị thời gian định dạng `HH:mm:ss`, tự động đổi màu Cam khi còn <= 15 phút,
/// màu Đỏ khi quá giờ, và hiển thị nút "Gia hạn +30 phút".
class CountdownTimerWidget extends StatefulWidget {
  /// Thời điểm hết hạn của phiên bàn.
  final DateTime expiresAt;

  /// Kích thước chữ hiển thị thời gian.
  final double fontSize;

  /// Ngưỡng thời gian cảnh báo (phút) để đổi sang màu cam (mặc định 15 phút).
  final int warningMinutes;

  /// Số phút cộng thêm hiển thị trên nút gia hạn (mặc định 30 phút).
  final int extendStepMinutes;

  /// Callback khi người dùng bấm nút Gia hạn.
  final VoidCallback? onExtend;

  /// Callback khi đồng hồ chạm mốc 00:00:00.
  final VoidCallback? onExpired;

  const CountdownTimerWidget({
    super.key,
    required this.expiresAt,
    this.fontSize = 32,
    this.warningMinutes = 15,
    this.extendStepMinutes = 30,
    this.onExtend,
    this.onExpired,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  late Duration _remaining;
  bool _expiredCalled = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final now = ClockService.instance.serverNow;
    _remaining = widget.expiresAt.difference(now);
  }

  void _tick() {
    setState(() {
      _updateRemaining();
    });

    if (_remaining.isNegative && !_expiredCalled) {
      _expiredCalled = true;
      widget.onExpired?.call();
    }
  }

  String _formatDuration(Duration d) {
    final totalSeconds = (d.inMilliseconds / 1000.0).round().abs();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (d.isNegative) {
      return '-$hStr:$mStr:$sStr';
    }
    return '$hStr:$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final isNegative = _remaining.isNegative;
    final totalSeconds = (_remaining.inMilliseconds / 1000.0).round();
    final totalMinutes = (totalSeconds / 60.0).ceil();

    Color timerColor;
    if (isNegative) {
      timerColor = AppColors.statusOvertime;
    } else if (totalMinutes <= widget.warningMinutes) {
      timerColor = AppColors.statusExpiring;
    } else {
      timerColor = AppColors.statusUsing;
    }

    final showExtendButton = (totalMinutes <= widget.warningMinutes || isNegative) && widget.onExtend != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatDuration(_remaining),
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: timerColor,
          ),
        ),
        if (showExtendButton) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: widget.onExtend,
            icon: const Icon(Icons.add_alarm, size: 20),
            label: Text('Gia hạn +${widget.extendStepMinutes} phút'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusExpiring,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ],
    );
  }
}

