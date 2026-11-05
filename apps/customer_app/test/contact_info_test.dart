import 'package:core/core.dart';
import 'package:customer_app/repositories/customer_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class ContactAuth extends AuthService {
  String? uid = 'customer';
  @override
  String? get currentUid => uid;
}

void main() {
  test('Contact update normalizes phone and preserves points and role', () async {
    final db = FakeFirebaseFirestore();
    final auth = ContactAuth();
    final repository = CustomerRepository(firestore: db, authService: auth,
      reservationService: ReservationService(firestore: db),
      sessionService: SessionService(firestore: db),
      orderService: OrderService(firestore: db));
    await db.doc('users/customer').set({'displayName': 'Old', 'phone': '0900000000',
      'role': 'customer', 'points': 37, 'email': 'customer@example.com', 'fcmTokens': ['device']});
    await repository.updateContactInfo(expectedUid: 'customer', displayName: '  Nguyễn An  ', phone: '+84 912 345 678');
    final data = (await db.doc('users/customer').get()).data()!;
    expect(data['displayName'], 'Nguyễn An');
    expect(data['phone'], '0912345678');
    expect(data['points'], 37);
    expect(data['role'], 'customer');
    expect(data['email'], 'customer@example.com');
    expect(data['fcmTokens'], ['device']);
  });

  test('Rejects invalid input and changed login without updating profile', () async {
    final db = FakeFirebaseFirestore();
    final auth = ContactAuth();
    final repository = CustomerRepository(firestore: db, authService: auth,
      reservationService: ReservationService(firestore: db),
      sessionService: SessionService(firestore: db),
      orderService: OrderService(firestore: db));
    await db.doc('users/customer').set({'role': 'customer', 'displayName': 'Old'});
    await expectLater(repository.updateContactInfo(expectedUid: 'customer', displayName: ' ', phone: '0912345678'), throwsArgumentError);
    await expectLater(repository.updateContactInfo(expectedUid: 'customer', displayName: 'An', phone: 'abc123'), throwsArgumentError);
    auth.uid = 'someone-else';
    await expectLater(repository.updateContactInfo(expectedUid: 'customer', displayName: 'An', phone: '0912345678'), throwsStateError);
    expect((await db.doc('users/customer').get()).data()!['displayName'], 'Old');
  });
}
