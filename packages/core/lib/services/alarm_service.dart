import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../constants/app_config.dart';
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
  final _alerts = StreamController<SessionAlarm>.broadcast();
  Stream<SessionAlarm> get alerts => _alerts.stream;
  final Map<String, DateTime> _expiryBySession = {};

  /// Bảng lưu vết các mốc thời gian đã phát chuông/rung của từng bàn.
  /// Cấu trúc: `{sessionId: {15, 5, 0}}`.
  /// Đảm bảo mỗi mốc thời gian chỉ phát cảnh báo đúng 1 lần duy nhất cho mỗi bàn.
  final Map<String, Set<int>> firedBySession = {};

  /// Khởi tạo cấu hình kênh thông báo và quyền rung trên thiết bị Android/iOS.
  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb) { _isInitialized = true; return; }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
    await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    _isInitialized = true;
  }

  /// Kiểm tra các mốc cảnh báo (15 phút, 5 phút, 0 phút) cho một phiên bàn đơn lẻ.
  /// Thường được gọi bởi ứng dụng Khách hàng (`customer_app`) khi theo dõi bàn của mình.
  Future<void> syncAlarmsForSession(SessionModel s,
      {AppConfig config = AppConfig.defaultConfig}) async {
    if (!s.isActive) return;
    if (_expiryBySession[s.id] != s.expiresAt) {
      resetSessionAlarms(s.id);
      _expiryBySession[s.id] = s.expiresAt;
    }
    final remaining = s.expiresAt.difference(ClockService.instance.serverNow);
    final thresholds = [...config.warnMinutes]..sort();
    final threshold = remaining <= Duration.zero
        ? 0
        : thresholds
            .where((value) => value > 0 && remaining <= Duration(minutes: value))
            .cast<int?>()
            .firstWhere((_) => true, orElse: () => null);
    if (threshold == null) return;
    final fired = firedBySession.putIfAbsent(s.id, () => <int>{});
    if (!fired.add(threshold)) return;
    await _triggerAlarm(
        sessionId: s.id,
        tableName: s.tableName,
        minutesLeft: threshold,
        title: threshold == 0
            ? 'Hết giờ dùng bàn!'
            : 'Nhắc nhở: Còn $threshold phút',
        body: threshold == 0
            ? '${s.tableName} đã hết giờ. Vui lòng thanh toán hoặc gia hạn.'
            : '${s.tableName} còn $threshold phút trước khi kết thúc phiên.');
  }

  /// Định kỳ mỗi giây hoặc mỗi lượt tick của đồng hồ quét toàn bộ danh sách phiên đang hoạt động.
  /// Thường được gọi bởi ứng dụng Phục vụ (`waiter_app`) và Quầy POS (`counter_app`).
  void onTickCheck(List<SessionModel> activeSessions,
      {AppConfig config = AppConfig.defaultConfig}) {
    for (final session in activeSessions) {
      syncAlarmsForSession(session, config: config);
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
    // In-app feedback remains available even when notification permission is denied.
    _alerts.add(SessionAlarm(sessionId: sessionId, title: title, body: body));
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
        'table_session_sound_v2',
        'Cảnh báo phiên bàn',
        channelDescription: 'Thông báo nhắc nhở xoay vòng bàn Cafe',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        vibrationPattern: null,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
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
    _expiryBySession.remove(sessionId);
  }
}

class SessionAlarm {
  final String sessionId;
  final String title;
  final String body;

  const SessionAlarm({required this.sessionId, required this.title, required this.body});
}
