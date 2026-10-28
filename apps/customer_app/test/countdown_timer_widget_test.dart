import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// Widget Test cho [CountdownTimerWidget] (Phụ trách: DƯƠNG BÙI - PRM393).
///
/// Yêu cầu kiểm thử bắt buộc theo Mục 7.2 của PROJECT_SPEC:
/// 1. Hiển thị đúng định dạng `HH:mm:ss`.
/// 2. Đổi sang màu Cam (`AppColors.statusExpiring`) khi thời gian còn <= 15 phút.
/// 3. Hiển thị nút "Gia hạn +30 phút" và kích hoạt callback `onExtend` khi người dùng bấm nút.
/// 4. Đổi sang màu Đỏ (`AppColors.statusOvertime`) và hiển thị dấu `-` khi đã quá giờ.
/// 5. Kiểm thử ngưỡng cảnh báo tùy biến linh hoạt qua `warningMinutes` và `extendStepMinutes`.
void main() {
  group('CountdownTimerWidget Tests (DƯƠNG BÙI)', () {
    testWidgets(
      '1. Hiển thị đúng định dạng HH:mm:ss và màu xanh khi thời gian còn > 15 phút',
      (tester) async {
        final serverNow = ClockService.instance.serverNow;
        // Hết hạn sau 1 tiếng 30 phút (90 phút) -> Còn nhiều hơn 15 phút
        final expiresAt = serverNow.add(const Duration(hours: 1, minutes: 30));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountdownTimerWidget(
                expiresAt: expiresAt,
              ),
            ),
          ),
        );

        // Kiểm tra text định dạng HH:mm:ss
        final timerFinder = find.text('01:30:00');
        expect(timerFinder, findsOneWidget);

        // Kiểm tra màu sắc mặc định là màu xanh 'using'
        final textWidget = tester.widget<Text>(timerFinder);
        expect(textWidget.style?.color, equals(AppColors.statusUsing));

        // Nút gia hạn KHÔNG hiển thị khi còn > 15 phút
        expect(find.text('Gia hạn +30 phút'), findsNothing);
      },
    );

    testWidgets(
      '2. Đổi sang màu Cam và hiển thị nút "Gia hạn +30 phút" khi thời gian còn <= 15 phút',
      (tester) async {
        final serverNow = ClockService.instance.serverNow;
        // Hết hạn sau 10 phút 15 giây (<= 15 phút)
        final expiresAt = serverNow.add(const Duration(minutes: 10, seconds: 15));
        bool onExtendCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountdownTimerWidget(
                expiresAt: expiresAt,
                onExtend: () {
                  onExtendCalled = true;
                },
              ),
            ),
          ),
        );

        // Kiểm tra text định dạng 00:10:15
        final timerFinder = find.text('00:10:15');
        expect(timerFinder, findsOneWidget);

        // Kiểm tra màu chữ là màu Cam expiring
        final textWidget = tester.widget<Text>(timerFinder);
        expect(textWidget.style?.color, equals(AppColors.statusExpiring));

        // Kiểm tra sự xuất hiện của nút gia hạn
        final extendButtonFinder = find.widgetWithText(ElevatedButton, 'Gia hạn +30 phút');
        expect(extendButtonFinder, findsOneWidget);

        // Bấm nút gia hạn và kiểm tra callback được kích hoạt
        await tester.tap(extendButtonFinder);
        await tester.pump();
        expect(onExtendCalled, isTrue);
      },
    );

    testWidgets(
      '3. Hiển thị màu Đỏ và dấu trừ (-) khi phiên đã quá giờ (Overtime)',
      (tester) async {
        final serverNow = ClockService.instance.serverNow;
        // Đã quá giờ 5 phút 20 giây trước
        final expiresAt = serverNow.subtract(const Duration(minutes: 5, seconds: 20));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountdownTimerWidget(
                expiresAt: expiresAt,
              ),
            ),
          ),
        );

        // Kiểm tra định dạng có dấu '-'
        final timerFinder = find.text('-00:05:20');
        expect(timerFinder, findsOneWidget);

        // Kiểm tra màu chữ là màu Đỏ overtime
        final textWidget = tester.widget<Text>(timerFinder);
        expect(textWidget.style?.color, equals(AppColors.statusOvertime));
      },
    );

    testWidgets(
      '4. Hỗ trợ cấu hình ngưỡng cảnh báo động warningMinutes và extendStepMinutes',
      (tester) async {
        final serverNow = ClockService.instance.serverNow;
        // Còn 20 phút. Nếu warningMinutes = 25 phút thì 20 phút đã nằm trong vùng cảnh báo!
        final expiresAt = serverNow.add(const Duration(minutes: 20));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountdownTimerWidget(
                expiresAt: expiresAt,
                warningMinutes: 25,
                extendStepMinutes: 45,
                onExtend: () {},
              ),
            ),
          ),
        );

        final timerFinder = find.text('00:20:00');
        expect(timerFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(timerFinder);
        expect(textWidget.style?.color, equals(AppColors.statusExpiring));

        // Nút gia hạn hiển thị số phút theo cấu hình động
        expect(find.widgetWithText(ElevatedButton, 'Gia hạn +45 phút'), findsOneWidget);
      },
    );
  });
}
