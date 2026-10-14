import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử logic thanh toán PaymentService.calculatePayment', () {
    test('1. Không dùng điểm: Tính đúng tiền thực thu và tích lũy 10.000đ = 1 điểm', () {
      final res = PaymentService.calculatePayment(
        subtotal: 100000,
        pointsUsed: 0,
      );

      expect(res.subtotal, equals(100000));
      expect(res.discount, equals(0));
      expect(res.total, equals(100000));
      expect(res.pointsEarned, equals(10)); // 100.000 / 10.000 = 10 điểm
      expect(res.totalBonusPoints, equals(0));
    });

    test('2. Đổi điểm hợp lệ dưới 50%: 30 điểm = 30.000đ giảm giá', () {
      final res = PaymentService.calculatePayment(
        subtotal: 100000,
        pointsUsed: 30, // 30.000đ (30% hóa đơn <= 50%)
      );

      expect(res.discount, equals(30000));
      expect(res.pointsUsed, equals(30));
      expect(res.total, equals(70000));
      expect(res.pointsEarned, equals(7)); // 70.000 / 10.000 = 7 điểm
    });

    test('3. Giới hạn đổi điểm tối đa 50%: Dùng 80 điểm cho hóa đơn 100.000đ chỉ được giảm tối đa 50.000đ (50 điểm)', () {
      final res = PaymentService.calculatePayment(
        subtotal: 100000,
        pointsUsed: 80, // Yêu cầu đổi 80.000đ (> 50%)
      );

      expect(res.discount, equals(50000)); // Bị chặn ở mức 50% của 100.000đ
      expect(res.pointsUsed, equals(50)); // Chỉ trừ 50 điểm thực tế
      expect(res.total, equals(50000));
      expect(res.pointsEarned, equals(5)); // 50.000 / 10.000 = 5 điểm
    });

    test('4. Cộng điểm thưởng trả bàn sớm: earlyReleaseBonusPoints = 20 điểm', () {
      final res = PaymentService.calculatePayment(
        subtotal: 100000,
        earlyReleased: true,
      );

      expect(res.bonusEarlyRelease, equals(20));
      expect(res.bonusPreOrder, equals(0));
      expect(res.totalBonusPoints, equals(20));
      expect(res.pointsEarned, equals(10));
    });

    test('5. Kết hợp cả trả bàn sớm (+20) và đặt món trước (+10): Tổng thưởng 30 điểm', () {
      final res = PaymentService.calculatePayment(
        subtotal: 120000,
        pointsUsed: 20, // Giảm 20.000đ
        earlyReleased: true, // +20 điểm
        hasPreOrder: true, // +10 điểm
      );

      expect(res.discount, equals(20000));
      expect(res.total, equals(100000));
      expect(res.pointsEarned, equals(10)); // 100.000 / 10.000 = 10
      expect(res.bonusEarlyRelease, equals(20));
      expect(res.bonusPreOrder, equals(10));
      expect(res.totalBonusPoints, equals(30));
    });
  });
}

