import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Revenue includes lower boundary and excludes next period with realtime updates',
      () async {
    final db = FakeFirebaseFirestore();
    final service = PaymentService(firestore: db);
    final start = DateTime.utc(2026, 11, 4, 17);
    final end = DateTime.utc(2026, 11, 5, 17);
    for (final entry in {
      'before': start.subtract(const Duration(seconds: 1)),
      'start': start,
      'end': end
    }.entries) {
      await db.doc('payments/${entry.key}').set({
        'paidAt': Timestamp.fromDate(entry.value),
        'total': 70000,
        'subtotal': 100000,
        'discount': 30000,
      });
    }
    final stream = service.watchPaymentsBetween(start, end);
    final payments = await stream.first;
    expect(payments.map((p) => p.id), ['start']);
    expect(payments.single.total, 70000);
    await db.doc('payments/new').set({
      'paidAt': Timestamp.fromDate(start.add(const Duration(hours: 1))),
      'total': 20000
    });
    final updated = await stream.first;
    expect(updated.map((p) => p.id), ['new', 'start']);
    expect(updated.fold<int>(0, (sum, p) => sum + p.total), 90000);
    expect(() => service.watchPaymentsBetween(end, start), throwsArgumentError);
  });
}
