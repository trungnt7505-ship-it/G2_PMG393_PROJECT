import 'dart:async';
import 'package:core/core.dart';
import 'package:counter_app/dialogs/payment_checkout_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemberAuth extends AuthService {
  final Completer<UserModel?> result = Completer();
  String? requestedUid;
  @override
  Future<UserModel?> findCustomerById(String uid) {
    requestedUid = uid;
    return result.future;
  }
}

void main() {
  for (final outcome in ['found', 'missing', 'error', 'disposed']) {
    testWidgets('Member UID lookup: $outcome', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = MemberAuth();
      final now = DateTime(2026);
      final session = SessionModel(
        id: 'session',
        tableId: 'table',
        tableName: 'Bàn 01',
        customerId: 'customer_from_qr',
        customerName: 'Khách',
        openedBy: 'cashier',
        openedByRole: 'counter',
        startedAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        subtotal: 100000,
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          appConfigProvider
              .overrideWith((ref) => Stream.value(AppConfig.defaultConfig)),
          sessionStreamProvider.overrideWith((ref, id) => Stream.value(session))
        ],
        child: MaterialApp(
            home: Scaffold(body: PaymentCheckoutModal(session: session))),
      ));
      expect(auth.requestedUid, 'customer_from_qr');
      expect(
          tester
              .widget<ElevatedButton>(
                  find.byKey(const Key('confirm_payment_button')))
              .onPressed,
          isNull);
      if (outcome == 'disposed') await tester.pumpWidget(const SizedBox());
      if (outcome == 'error') {
        auth.result.completeError(Exception('network unavailable'));
      } else {
        auth.result.complete(outcome == 'missing'
            ? null
            : UserModel(
                id: 'customer_from_qr',
                role: 'customer',
                displayName: 'Khách QR',
                phone: '0901234567',
                email: 'customer@example.com',
                points: 80,
                createdAt: now,
              ));
      }
      await tester.pumpAndSettle();
      if (outcome == 'found') {
        expect(find.text('Khách QR'), findsOneWidget);
        await tester.enterText(
            find.byKey(const Key('points_input_field')), '60');
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<TextField>(find.byKey(const Key('points_input_field')))
                .controller!
                .text,
            '50');
      } else if (outcome == 'missing') {
        expect(find.text('Không tìm thấy thành viên hợp lệ với mã QR này.'),
            findsOneWidget);
      } else if (outcome == 'error') {
        expect(find.textContaining('network unavailable'), findsOneWidget);
      }
    });
  }
}
