import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:customer_app/repositories/customer_repository.dart';
import 'package:customer_app/viewmodels/reservation_booking_viewmodel.dart';
import 'package:customer_app/viewmodels/active_session_viewmodel.dart';
import 'package:customer_app/viewmodels/home_viewmodel.dart';

class _FakeCustomerRepository implements CustomerRepository {
  int submittedOrders = 0;
  int submittedTakeawayOrders = 0;
  DateTime? submittedPickupAt;

  @override
  Future<String> submitOrder({
    required String sessionId,
    required String tableId,
    required String tableName,
    required List<OrderItemModel> items,
    required String createdBy,
  }) async {
    submittedOrders++;
    expect(sessionId, 'session');
    expect(tableId, 'table');
    expect(tableName, 'Bàn 01');
    expect(createdBy, 'customer');
    expect(items, hasLength(1));
    return 'order';
  }

  @override
  Future<String> submitTakeawayOrder({
    required List<OrderItemModel> items,
    required String createdBy,
    required String customerName,
    required String customerPhone,
    required DateTime pickupAt,
  }) async {
    submittedTakeawayOrders++;
    submittedPickupAt = pickupAt;
    expect(createdBy, 'customer');
    expect(customerName, 'Khách');
    expect(customerPhone, '090');
    expect(items, hasLength(1));
    return 'takeaway-order';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Customer App Logic & ViewModels Tests (DƯƠNG BÙI)', () {
    test(
        '1. Tính đúng thành tiền món kèm options phụ thu và số lượng (OrderItemModel)',
        () {
      final item = OrderItemModel(
        itemId: 'cf_sua',
        name: 'Cà phê sữa',
        unitPrice: 35000,
        qty: 2,
        selectedOptions: const [
          SelectedOption(
              groupName: 'Size', choiceName: 'Size L', extraPrice: 5000),
          SelectedOption(
              groupName: 'Topping',
              choiceName: 'Thạch cà phê',
              extraPrice: 5000),
        ],
      );

      // Giá 1 ly: 35.000 + 5.000 + 5.000 = 45.000đ
      // Tổng cho 2 ly: 45.000 * 2 = 90.000đ
      expect(item.totalPrice, equals(90000));
    });

    test(
        '2. ReservationBookingState quản lý giỏ món đặt trước và cờ hasPreOrder',
        () {
      var state = ReservationBookingState(
        startTime: DateTime.now().add(const Duration(hours: 2)),
      );

      expect(state.hasPreOrder, isFalse);
      expect(state.preOrderTotal, equals(0));

      final item1 = const OrderItemModel(
        itemId: 'item_1',
        name: 'Trà đào',
        unitPrice: 40000,
        qty: 1,
      );

      final item2 = const OrderItemModel(
        itemId: 'item_2',
        name: 'Bánh croissant',
        unitPrice: 30000,
        qty: 2,
      );

      state = state.copyWith(preOrderItems: [item1, item2]);

      expect(state.hasPreOrder, isTrue);
      // 40.000 + (30.000 * 2) = 100.000đ
      expect(state.preOrderTotal, equals(100000));
    });

    test(
        '3. ActiveSessionState quản lý giỏ món gọi thêm tại bàn và tính tổng tiền',
        () {
      var state = const ActiveSessionState();
      expect(state.draftCart, isEmpty);
      expect(state.draftCartTotal, equals(0));

      final item = const OrderItemModel(
        itemId: 'item_cf',
        name: 'Bạc xỉu',
        unitPrice: 35000,
        qty: 3,
      );

      state = state.copyWith(draftCart: [item]);
      expect(state.draftCart.length, equals(1));
      expect(state.draftCartTotal, equals(105000));
    });

    test('Home menu cart submits order to the active waiter queue', () async {
      final repository = _FakeCustomerRepository();
      final vm = HomeViewModel(repository: repository);
      vm.addToCart(const OrderItemModel(
        itemId: 'item_cf',
        name: 'Bạc xỉu',
        unitPrice: 35000,
        qty: 2,
      ));

      expect(vm.state.draftCartTotal, 70000);
      final submitted = await vm.submitOrder(
        session: SessionModel(
          id: 'session',
          tableId: 'table',
          tableName: 'Bàn 01',
          customerName: 'Khách',
          openedBy: 'counter',
          openedByRole: 'counter',
          startedAt: DateTime(2026),
          expiresAt: DateTime(2026, 1, 1, 2),
        ),
        uid: 'customer',
      );

      expect(submitted, isTrue);
      expect(repository.submittedOrders, 1);
      expect(vm.state.draftCart, isEmpty);
      expect(vm.state.orderSuccess, contains('gửi'));
      vm.dispose();
    });

    test('Home menu cart submits a scheduled takeaway order', () async {
      final repository = _FakeCustomerRepository();
      final vm = HomeViewModel(repository: repository);
      vm.addToCart(const OrderItemModel(
        itemId: 'item_cf',
        name: 'Bạc xỉu',
        unitPrice: 35000,
        qty: 2,
      ));
      final pickupAt = DateTime.now().add(const Duration(hours: 1));

      final submitted = await vm.submitTakeawayOrder(
        uid: 'customer',
        customerName: 'Khách',
        customerPhone: '090',
        pickupAt: pickupAt,
      );

      expect(submitted, isTrue);
      expect(repository.submittedTakeawayOrders, 1);
      expect(repository.submittedPickupAt, pickupAt);
      expect(vm.state.draftCart, isEmpty);
      expect(vm.state.orderSuccess, contains('mang đi'));
      vm.dispose();
    });

    test(
        '4. ReservationBookingViewModel kiểm tra lỗi chọn bàn và quản lý trạng thái isSubmitting an toàn',
        () async {
      final vm = ReservationBookingViewModel(
        reservationService: ReservationService(),
      );

      final user = UserModel(
        id: 'cust_01',
        role: 'customer',
        displayName: 'Anh Dương',
        phone: '0901234567',
        email: 'duong@test.com',
        points: 50,
        fcmTokens: const [],
        createdAt: DateTime.now(),
      );

      // Thử submit khi chưa chọn bàn -> Phải trả về null và ghi nhận errorMessage, không bị treo
      final resId = await vm.submitReservation(
        user: user,
        config: AppConfig.defaultConfig,
      );

      expect(resId, isNull);
      expect(vm.state.isSubmitting, isFalse);
      expect(vm.state.errorMessage, contains('Vui lòng chọn bàn'));
    });
  });
}
