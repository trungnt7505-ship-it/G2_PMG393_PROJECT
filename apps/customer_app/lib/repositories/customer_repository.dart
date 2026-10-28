import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Repository đóng vai trò tầng trung gian trừu tượng hóa dữ liệu cho Customer App.
///
/// Tuân thủ quy định:
/// - Không để logic truy vấn Firestore trực tiếp trong Widget hay View.
/// - Đảm bảo dữ liệu lịch sử điểm (`pointTx`) và hóa đơn (`payments`) được truy vấn
///   đúng theo quyền sở hữu tài khoản khách hàng (`isOwner` / `customerId == auth.uid`).
class CustomerRepository {
  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final ReservationService _reservationService;
  final SessionService _sessionService;
  final OrderService _orderService;

  CustomerRepository({
    FirebaseFirestore? firestore,
    required AuthService authService,
    required ReservationService reservationService,
    required SessionService sessionService,
    required OrderService orderService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService,
        _reservationService = reservationService,
        _sessionService = sessionService,
        _orderService = orderService;

  /// Lấy UID người dùng hiện tại từ AuthService.
  String? get currentUid => _authService.currentUid;

  /// Stream theo dõi phiên đang hoạt động (`active` hoặc `billing`) của khách hàng hiện tại.
  /// Giúp hiển thị banner bàn đang ngồi ngay trên màn hình chính (CustomerHomeScreen).
  Stream<SessionModel?> watchActiveSessionForCustomer(String customerId) {
    if (customerId.isEmpty) return Stream.value(null);

    return _firestore
        .collection('sessions')
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: ['active', 'billing'])
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return SessionModel.fromMap(doc.data(), doc.id);
        });
  }

  /// Stream danh sách lịch sử biến động điểm (`users/{uid}/pointTx`).
  /// Được bảo vệ bởi Security Rules: `allow read: if isOwner(userId)`.
  Stream<List<PointTxModel>> watchCustomerPointTx(String customerId) {
    if (customerId.isEmpty) return Stream.value(const []);

    return _firestore
        .collection('users')
        .doc(customerId)
        .collection('pointTx')
        .orderBy('at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PointTxModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream danh sách lịch sử hóa đơn thanh toán của khách (`payments`).
  /// Được bảo vệ bởi Security Rules: `resource.data.customerId == request.auth.uid`.
  Stream<List<PaymentModel>> watchCustomerPayments(String customerId) {
    if (customerId.isEmpty) return Stream.value(const []);

    return _firestore
        .collection('payments')
        .where('customerId', isEqualTo: customerId)
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Đọc chi tiết các món trong hóa đơn đã thanh toán để xem lại snapshot.
  Future<List<OrderItemModel>> getPaymentItems(String paymentId) {
    return PaymentService(firestore: _firestore).getPaymentItems(paymentId);
  }

  /// Đăng xuất tài khoản khách hàng.
  Future<void> signOut() => _authService.signOut();

  /// Hủy đặt bàn của khách.
  Future<void> cancelReservation(String reservationId) {
    return _reservationService.cancelReservation(reservationId);
  }

  /// Check-in nhận bàn qua chuỗi mã QR bàn: `cafe://table/{tableId}?k={qrSecret}`.
  Future<String> checkInByTableQr({
    required String qrContent,
    required String customerId,
    String? reservationId,
  }) {
    return _sessionService.checkInByTableQr(
      qrContent: qrContent,
      customerId: customerId,
      reservationId: reservationId,
    );
  }

  /// Gia hạn phiên bàn hiện tại.
  Future<int> extendSession(String sessionId, {required String byUid}) {
    return _sessionService.extendSession(sessionId, byUid: byUid);
  }

  /// Yêu cầu xin trả bàn sớm để nhận điểm thưởng `earlyReleaseBonusPoints`.
  Future<void> requestEarlyRelease(String sessionId, {required String customerId}) {
    return _sessionService.requestEarlyRelease(sessionId, customerId: customerId);
  }

  /// Gửi yêu cầu hỗ trợ (gọi phục vụ hoặc xin tính tiền).
  Future<void> sendTableRequest({
    required String sessionId,
    required String tableId,
    required String tableName,
    required RequestType type,
    required String createdBy,
    String message = '',
  }) {
    return _sessionService.sendTableRequest(
      sessionId: sessionId,
      tableId: tableId,
      tableName: tableName,
      type: type,
      createdBy: createdBy,
      message: message,
    );
  }

  /// Gửi đơn gọi món với vai trò `customer` -> trạng thái khởi tạo là `pending`.
  Future<String> submitOrder({
    required String sessionId,
    required String tableId,
    required String tableName,
    required List<OrderItemModel> items,
    required String createdBy,
  }) {
    return _orderService.submitOrder(
      sessionId: sessionId,
      tableId: tableId,
      tableName: tableName,
      items: items,
      createdBy: createdBy,
      createdByRole: 'customer',
      type: OrderType.dine_in,
    );
  }
}

/// Provider cho [CustomerRepository].
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(
    authService: ref.watch(authServiceProvider),
    reservationService: ref.watch(reservationServiceProvider),
    sessionService: ref.watch(sessionServiceProvider),
    orderService: ref.watch(orderServiceProvider),
  );
});

/// StreamProvider theo dõi phiên bàn đang dùng của khách hàng hiện tại.
final activeCustomerSessionProvider = StreamProvider<SessionModel?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(customerRepositoryProvider).watchActiveSessionForCustomer(user.id);
});

/// StreamProvider theo dõi lịch sử biến động điểm tích lũy của khách hàng hiện tại.
final customerPointTxProvider = StreamProvider<List<PointTxModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(customerRepositoryProvider).watchCustomerPointTx(user.id);
});

/// StreamProvider theo dõi lịch sử các hóa đơn thanh toán của khách hàng hiện tại.
final customerPaymentsProvider = StreamProvider<List<PaymentModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(customerRepositoryProvider).watchCustomerPayments(user.id);
});
