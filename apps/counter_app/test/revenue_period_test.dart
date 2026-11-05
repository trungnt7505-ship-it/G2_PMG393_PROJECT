import 'package:counter_app/models/revenue_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/screens/revenue_report_screen.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Phone layout displays revenue and switches period queries', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ranges = <({DateTime start, DateTime end})>[];
    await tester.pumpWidget(ProviderScope(overrides: [
      revenuePaymentsProvider.overrideWith((ref, range) {
        ranges.add(range);
        return Stream.value(<PaymentModel>[]);
      }),
    ], child: const MaterialApp(home: RevenueReportScreen())));
    await tester.pumpAndSettle();
    expect(find.text('0 đ'), findsOneWidget);
    expect(find.text('Chưa có hóa đơn thanh toán trong kỳ này.'), findsOneWidget);
    expect(ranges.last.end.difference(ranges.last.start).inDays, 1);
    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();
    expect(ranges.last.end.difference(ranges.last.start).inDays, 7);
    await tester.tap(find.text('Tháng'));
    await tester.pumpAndSettle();
    expect(ranges.last.end.difference(ranges.last.start).inDays, greaterThanOrEqualTo(28));
    expect(tester.takeException(), isNull);
  });
  test('Vietnam day starts at 17 UTC on previous calendar date', () {
    final range = RevenuePeriod.day.range(DateTime(2026, 11, 5));
    expect(range.start, DateTime.utc(2026, 11, 4, 17));
    expect(range.end, DateTime.utc(2026, 11, 5, 17));
  });
  test('Sunday belongs to Monday-based week across a year boundary', () {
    final range = RevenuePeriod.week.range(DateTime(2027, 1, 3));
    expect(range.start, DateTime.utc(2026, 12, 27, 17));
    expect(range.end, DateTime.utc(2027, 1, 3, 17));
  });
  test('Month handles leap February and December rollover', () {
    final february = RevenuePeriod.month.range(DateTime(2028, 2, 15));
    expect(february.end.difference(february.start).inDays, 29);
    final december = RevenuePeriod.month.range(DateTime(2026, 12, 10));
    expect(december.end, DateTime.utc(2026, 12, 31, 17));
  });
}
