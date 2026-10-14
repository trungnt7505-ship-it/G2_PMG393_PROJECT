import 'package:cloud_firestore/cloud_firestore.dart';

/// Dịch vụ đồng bộ thời gian giữa Client và Firebase Server.
/// Đảm bảo tính toán giờ hết hạn phiên, đồng hồ đếm ngược và kiểm tra quá giờ
/// không bị ảnh hưởng bởi việc người dùng chỉnh sai giờ trên thiết bị cá nhân.
class ClockService {
  ClockService._();

  /// Singleton instance duy nhất trong toàn bộ hệ thống.
  static final ClockService instance = ClockService._();

  Duration _offset = Duration.zero;

  /// Độ chênh lệch giữa giờ Server và giờ thiết bị Client.
  Duration get offset => _offset;

  /// Lấy thời điểm hiện tại đã được đồng bộ chuẩn theo Server Firestore.
  /// BẮT BUỘC dùng thuộc tính này thay cho `DateTime.now()` trong mọi phép tính phiên bàn.
  DateTime get serverNow => DateTime.now().add(_offset);

  /// Đồng bộ giờ Server bằng cách ghi và đọc lại `FieldValue.serverTimestamp()`.
  /// [uid]: UID của người dùng đang đăng nhập để tạo tài liệu tạm thời.
  Future<void> syncClock(String uid) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('config').doc('clock_sync_$uid');
      final clientBefore = DateTime.now();

      await docRef.set({
        'serverTime': FieldValue.serverTimestamp(),
      });

      final snapshot = await docRef.get();
      final clientAfter = DateTime.now();

      final serverTimestamp = snapshot.data()?['serverTime'] as Timestamp?;
      if (serverTimestamp != null) {
        final serverTime = serverTimestamp.toDate();
        // Ước lượng độ trễ mạng một chiều (khứ hồi / 2)
        final halfLatency = clientAfter.difference(clientBefore) ~/ 2;
        final estimatedClientAtServer = clientBefore.add(halfLatency);
        _offset = serverTime.difference(estimatedClientAtServer);
      }

      // Xóa tài liệu đồng bộ tạm thời
      await docRef.delete().catchError((_) {});
    } catch (_) {
      // Nếu offline hoặc lỗi mạng, giữ nguyên offset hiện tại
    }
  }

  /// Cho phép thiết lập độ lệch thủ công trong môi trường Unit Test.
  void setOffsetForTesting(Duration testOffset) {
    _offset = testOffset;
  }
}

