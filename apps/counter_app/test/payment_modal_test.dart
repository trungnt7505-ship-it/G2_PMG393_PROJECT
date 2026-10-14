import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:counter_app/dialogs/payment_checkout_modal.dart';

void main() {
  testWidgets(
    'Kiểm thử giao diện thanh toán tự động giới hạn số điểm nhập vào không vượt quá 50% tổng tiền tạm tính',
    (tester) async {
      // 1. Giả lập phiên bàn có tổng tạm tính = 100.000đ
      final testSession = SessionModel(
        id: 'session_test',
        tableId: 'table_01',
        tableName: 'Bàn 01',
        customerId: 'user_test',
        customerName: 'Nguyễn Văn Test',
        openedBy: 'counter_01',
        openedByRole: 'counter',
        startedAt: DateTime.now().subtract(const Duration(minutes: 60)),
        expiresAt: DateTime.now().add(const Duration(minutes: 60)),
        status: 'active',
        subtotal: 100000, // 100.000đ
      );

      // 2. Giả lập thành viên đang có 100 điểm tích lũy (tương đương 100.000đ)
      final testMember = UserModel(
        id: 'user_test',
        role: 'customer',
        displayName: 'Nguyễn Văn Test',
        phone: '0912345678',
        email: 'test@cafe.com',
        points: 100, // 100 điểm
        createdAt: DateTime.now(),
      );

      // Render modal với kích thước tablet
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PaymentCheckoutModal(
                session: testSession,
                initialMember: testMember,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tên thành viên và tạm tính hiển thị đúng
      expect(find.text('Nguyễn Văn Test'), findsOneWidget);

      final pointsInputFinder = find.byKey(const Key('points_input_field'));
      expect(pointsInputFinder, findsOneWidget);

      // Nhập 80 điểm (80.000đ > 50% của 100.000đ)
      await tester.enterText(pointsInputFinder, '80');
      await tester.pumpAndSettle();

      // Hệ thống phải tự động giới hạn / chặn về mức tối đa 50 điểm
      final textField = tester.widget<TextField>(pointsInputFinder);
      expect(textField.controller?.text, equals('50'));

      // Kiểm tra số tiền thực thu là 50.000đ (100.000đ - 50.000đ)
      expect(find.textContaining('50.000'), findsWidgets);
    },
  );
}
