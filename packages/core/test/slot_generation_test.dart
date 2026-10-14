import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử TableSlotModel.slotTimes và sinh khóa slot', () {
    final start = DateTime(2026, 10, 14, 14, 0, 0);

    test('1. Sinh đúng 5 ô giữ chỗ liên tiếp với bước nhảy chính xác 30 phút', () {
      final slots = TableSlotModel.slotTimes(start);

      // Đảm bảo số lượng slot chính xác bằng 5
      expect(slots.length, equals(5));

      // Mốc 1: 14:00 (0 phút)
      expect(slots[0], equals(start));

      // Mốc 2: 14:30 (+30 phút)
      expect(slots[1], equals(start.add(const Duration(minutes: 30))));

      // Mốc 3: 15:00 (+60 phút)
      expect(slots[2], equals(start.add(const Duration(minutes: 60))));

      // Mốc 4: 15:30 (+90 phút)
      expect(slots[3], equals(start.add(const Duration(minutes: 90))));

      // Mốc 5: 16:00 (+120 phút)
      expect(slots[4], equals(start.add(const Duration(minutes: 120))));
    });

    test('2. Kiểm tra khoảng cách giữa từng cặp slot liền kề đúng bằng 30 phút', () {
      final slots = TableSlotModel.slotTimes(start);

      for (var i = 0; i < slots.length - 1; i++) {
        final diff = slots[i + 1].difference(slots[i]).inMinutes;
        expect(diff, equals(30), reason: 'Khoảng cách giữa slot $i và ${i + 1} phải là 30 phút');
      }
    });

    test('3. Định dạng chuỗi khóa slot yyyyMMddHHmm chuẩn xác', () {
      final keys = TableSlotModel.generateSlotKeys(start);

      expect(keys.length, equals(5));
      expect(keys[0], equals('202610141400'));
      expect(keys[1], equals('202610141430'));
      expect(keys[2], equals('202610141500'));
      expect(keys[3], equals('202610141530'));
      expect(keys[4], equals('202610141600'));
    });
  });
}

