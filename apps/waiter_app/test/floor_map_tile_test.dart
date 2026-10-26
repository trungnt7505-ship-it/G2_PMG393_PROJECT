import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:waiter_app/widgets/table_tile_widget.dart';

void main() {
  group('TableTileWidget Unit/Widget Tests', () {
    testWidgets('Hiển thị đúng tên bàn, khu vực và sức chứa ở trạng thái bàn trống (Free)',
        (WidgetTester tester) async {
      final table = TableModel(
        id: 'table_01',
        name: 'Bàn 01',
        zone: 'Tầng 1',
        capacity: 4,
        status: 'available',
        qrSecret: 'secret_1',
      );

      final now = DateTime(2026, 10, 26, 12, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableTileWidget(
              table: table,
              now: now,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Bàn 01'), findsOneWidget);
      expect(find.text('Tầng 1'), findsOneWidget);
      expect(find.text('4 chỗ'), findsOneWidget);
      expect(find.text('Bàn trống'), findsOneWidget);
      expect(find.text('Sẵn sàng đón khách'), findsOneWidget);
      expect(find.byKey(const Key('release_table_button')), findsNothing);
    });

    testWidgets('Bật nút "Yêu cầu nhả bàn" và đổi sang màu Đỏ khi phiên ở trạng thái Quá giờ (Overtime)',
        (WidgetTester tester) async {
      final table = TableModel(
        id: 'table_02',
        name: 'Bàn 02',
        zone: 'Tầng 2',
        capacity: 2,
        status: 'occupied',
        currentSessionId: 'session_02',
        qrSecret: 'secret_2',
      );

      // Mốc thời gian hiện tại là 13:00, phiên bàn đã hết hạn từ 12:30 (quá giờ 30 phút)
      final now = DateTime(2026, 10, 26, 13, 0);
      final activeSession = SessionModel(
        id: 'session_02',
        tableId: 'table_02',
        tableName: 'Bàn 02',
        customerName: 'Nguyễn Văn A',
        openedBy: 'waiter_01',
        openedByRole: 'waiter',
        startedAt: DateTime(2026, 10, 26, 10, 0),
        baseMinutes: 120,
        extendedMinutes: 0,
        expiresAt: DateTime(2026, 10, 26, 12, 0), // Đã hết hạn
        status: 'active',
        subtotal: 150000,
      );

      bool requestReleaseCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableTileWidget(
              table: table,
              activeSession: activeSession,
              now: now,
              onTap: () {},
              onRequestRelease: () {
                requestReleaseCalled = true;
              },
            ),
          ),
        ),
      );

      // Đảm bảo hiển thị đúng nhãn Quá giờ
      expect(find.text('Quá giờ'), findsOneWidget);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);

      // Đảm bảo hiển thị nút "Yêu cầu nhả bàn"
      final releaseButtonFinder = find.byKey(const Key('release_table_button'));
      expect(releaseButtonFinder, findsOneWidget);

      // Bấm vào nút "Yêu cầu nhả bàn"
      await tester.tap(releaseButtonFinder);
      await tester.pump();

      expect(requestReleaseCalled, isTrue);
    });
  });
}
