import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_config.dart';

/// Lưu cấu hình hợp lệ mà không xóa các trường mở rộng của ứng dụng khác.
class ConfigService {
  final FirebaseFirestore? _customFirestore;
  ConfigService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  /// Đọc cấu hình tại thời điểm thực hiện nghiệp vụ; thiếu document thì dùng mặc định.
  Future<AppConfig> read({Transaction? transaction}) async {
    final ref = (_customFirestore ?? FirebaseFirestore.instance)
        .collection('config')
        .doc('app');
    final doc =
        transaction == null ? await ref.get() : await transaction.get(ref);
    final config = AppConfig.fromMap(doc.data() ?? {});
    config.validate();
    return config;
  }

  Future<void> save(AppConfig config, {AppConfig? expected}) async {
    config.validate();
    final db = _customFirestore ?? FirebaseFirestore.instance;
    final ref = db.collection('config').doc('app');
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (expected != null) {
        final current = AppConfig.fromMap(doc.data() ?? {}).toMap();
        final previous = expected.toMap();
        if (current.keys.any(
            (key) => current[key].toString() != previous[key].toString())) {
          throw StateError(
              'Cấu hình đã được thay đổi ở máy khác. Hãy tải lại trước khi lưu.');
        }
      }
      tx.set(ref, {...?doc.data(), ...config.toMap()});
    });
  }
}
