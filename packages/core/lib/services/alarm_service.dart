import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../models/session_model.dart';
import 'clock_service.dart';

/// Dịch vụ quản lý cảnh báo giờ hết hạn phiên bàn (Rung Haptic & Local Notifications).
/// Hỗ trợ đa bàn độc lập cho máy Phục vụ và Quầy POS (theo dõi cùng lúc nhiều bàn mà không nuốt thông báo).
class AlarmService {
  AlarmService._();

  /// Singleton instance của AlarmService.
  static final AlarmService instance = AlarmService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Bảng lưu vết các mốc thời gian đã phát chuông/rung của từng bàn.
  /// Cấu trúc: `{sessionId: {15, 5, 0}}`.
  /// Đảm bảo mỗi mốc thời gian chỉ phát cảnh báo đúng 1 lần duy nhất cho mỗi bàn.
  final Map<String, Set<int>> firedBySession = {};

  /// Khởi tạo cấu hình kênh thông báo và quyền rung trên thiết bị Android/iOS.
  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
    _isInitialized = true;
  }

  /// Kiểm tra các mốc cảnh báo (15 phút, 5 phút, 0 phút) cho một phiên bàn đơn lẻ.
  /// Thường được gọi bởi ứng dụng Khách hàng (`customer_app`) khi theo dõi bàn của mình.
  Future<void> syncAlarmsForSession(SessionModel s) async {
    if (!s.isActive) return;

    final now = ClockService.instance.serverNow;
    final remainingMinutes = s.expiresAt.difference(now).inMinutes;

    firedBySession.putIfAbsent(s.id, () => <int>{});
    final firedSet = firedBySession[s.id]!;

    if (remainingMinutes <= 0) {
      if (!firedSet.contains(0)) {
        firedSet.add(0);
        await _triggerAlarm(
          sessionId: s.id,
          tableName: s.tableName,
          minutesLeft: 0,
          title: 'Hết giờ dùng bàn!',
          body: '${s.tableName} đã hết thời lượng 120 phút. Vui lòng thanh toán hoặc yêu cầu nhân viên hỗ trợ.',
        );
      }
    } else if (remainingMinutes <= 5) {
      if (!firedSet.contains(5)) {
        firedSet.add(5);
        await _triggerAlarm(
          sessionId: s.id,
          tableName: s.tableName,
          minutesLeft: 5,
          title: 'Cảnh báo: Còn 5 phút!',
          body: '${s.tableName} chỉ còn 5 phút trước khi kết thúc phiên. Bạn có thể bấm Gia hạn ngay.',
        );
      }
    } else if (remainingMinutes <= 15) {
      if (!firedSet.contains(15)) {
        firedSet.add(15);
        await _triggerAlarm(
          sessionId: s.id,
          tableName: s.tableName,
          minutesLeft: 15,
          title: 'Nhắc nhở: Còn 15 phút',
          body: '${s.tableName} còn 15 phút trong phiên dùng bàn tiêu chuẩn.',
        );
      }
    }
  }

  /// Định kỳ mỗi giây hoặc mỗi lượt tick của đồng hồ quét toàn bộ danh sách phiên đang hoạt động.
  /// Thường được gọi bởi ứng dụng Phục vụ (`waiter_app`) và Quầy POS (`counter_app`).
  void onTickCheck(List<SessionModel> activeSessions) {
    for (final session in activeSessions) {
      syncAlarmsForSession(session);
    }
  }

  /// Kích hoạt rung Haptic và hiển thị thông báo đẩy cục bộ.
  Future<void> _triggerAlarm({
    required String sessionId,
    required String tableName,
    required int minutesLeft,
    required String title,
    required String body,
  }) async {
    // 1. Rung thiết bị (Vibration)
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        if (minutesLeft == 0) {
          // Hết giờ: Rung 3 nhịp mạnh
          Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 800]);
        } else {
          // Nhắc nhở: Rung 1 nhịp ngắn
          Vibration.vibrate(duration: 400);
        }
      }
    } catch (_) {
      // Bỏ qua lỗi rung trên thiết bị giả lập hoặc không hỗ trợ phần cứng
    }

    // 2. Hiển thị thông báo cục bộ
    try {
      const androidDetails = AndroidNotificationDetails(
        'table_session_channel',
        'Cảnh báo phiên bàn',
        channelDescription: 'Thông báo nhắc nhở xoay vòng bàn Cafe',
        importance: Importance.max,
        priority: Priority.high,
        vibrationPattern: null,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      final notificationId = (sessionId.hashCode ^ minutesLeft).abs() % 100000;
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
      );
    } catch (_) {
      // Bỏ qua lỗi thông báo nếu chưa được cấp quyền
    }
  }

  /// Xóa bộ nhớ cảnh báo của một phiên khi phiên được gia hạn thêm giờ hoặc đóng bàn.
  void resetSessionAlarms(String sessionId) {
    firedBySession.remove(sessionId);
  }
}

