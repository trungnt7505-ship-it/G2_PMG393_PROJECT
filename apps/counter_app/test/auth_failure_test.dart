import 'package:core/core.dart';
import 'package:counter_app/viewmodels/auth_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FailedAuth implements AuthService {
  @override
  Future<UserModel> signInWithEmail(String email, String password,
      {required List<UserRole> allowedRoles}) async => throw StateError('invalid credentials');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
void main() {
  for (final email in ['counter@cafe.com', 'manager@cafe.com']) {
    test('Firebase login failure cannot become fake POS login for $email', () async {
      final vm = AuthViewModel(FailedAuth());
      expect(await vm.signIn(email, '123456'), isFalse);
      expect(vm.state.user, isNull);
      expect(vm.state.errorMessage, isNotNull);
      vm.dispose();
    });
  }
}
