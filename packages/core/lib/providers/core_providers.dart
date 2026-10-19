import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_config.dart';
import '../constants/enums.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../models/payment_model.dart';
import '../models/request_model.dart';
import '../models/reservation_model.dart';
import '../models/session_model.dart';
import '../models/table_model.dart';
import '../models/user_model.dart';
import '../services/alarm_service.dart';
import '../services/auth_service.dart';
import '../services/clock_service.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';
import '../services/reservation_service.dart';
import '../services/seed_service.dart';
import '../services/config_service.dart';
import '../services/session_service.dart';

// ==========================================
// 1. SERVICE PROVIDERS
// ==========================================

/// Provider cho [ClockService] đồng bộ thời gian máy chủ.
final clockServiceProvider = Provider<ClockService>((ref) {
  return ClockService.instance;
});

/// Provider cho [AuthService] xác thực người dùng.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider cho [ReservationService] quản lý đặt bàn.
final reservationServiceProvider = Provider<ReservationService>((ref) {
  return ReservationService();
});

/// Provider cho [SessionService] quản lý phiên bàn.
final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService();
});

/// Provider cho [OrderService] quản lý gọi món.
final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService();
});

/// Provider cho [PaymentService] thanh toán và tích điểm.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});

/// Provider cho [AlarmService] cảnh báo âm thanh/rung.
final alarmServiceProvider = Provider<AlarmService>((ref) {
  return AlarmService.instance;
});

/// Provider cho [SeedService] khởi tạo dữ liệu mẫu.
final seedServiceProvider = Provider<SeedService>((ref) {
  return SeedService();
});

// ==========================================
// 2. REALTIME DATA STREAM PROVIDERS
// ==========================================

/// Stream thông tin người dùng đang đăng nhập hiện tại.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(authServiceProvider).watchCurrentUser();
});

/// Stream cấu hình ứng dụng từ `config/app`.
final appConfigProvider = StreamProvider<AppConfig>((ref) {
  return FirebaseFirestore.instance
      .collection('config')
      .doc('app')
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) {
      return AppConfig.defaultConfig;
    }
    return AppConfig.fromMap(doc.data()!);
  });
});

/// Stream danh sách tất cả các bàn trong quán.
final allTablesProvider = StreamProvider<List<TableModel>>((ref) {
  return ref.watch(sessionServiceProvider).watchAllTables();
});

/// Stream danh sách tất cả các phiên bàn đang hoạt động (`active` hoặc `billing`).
final activeSessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  return ref.watch(sessionServiceProvider).watchActiveSessions();
});

/// Stream danh sách các yêu cầu hỗ trợ đang mở (`open`).
final openRequestsProvider = StreamProvider<List<RequestModel>>((ref) {
  return ref.watch(sessionServiceProvider).watchOpenRequests();
});

/// Stream danh sách các đơn đặt bàn confirmed trong ngày hôm nay.
final todayConfirmedReservationsProvider =
    StreamProvider<List<ReservationModel>>((ref) {
  return ref
      .watch(reservationServiceProvider)
      .watchTodayConfirmedReservations();
});

/// Stream danh sách đặt bàn của một khách hàng cụ thể.
final customerReservationsProvider =
    StreamProvider.family<List<ReservationModel>, String>((ref, customerId) {
  return ref
      .watch(reservationServiceProvider)
      .watchCustomerReservations(customerId);
});

/// Stream thông tin chi tiết một phiên bàn theo `sessionId`.
final sessionStreamProvider =
    StreamProvider.family<SessionModel?, String>((ref, sessionId) {
  return ref.watch(sessionServiceProvider).watchSession(sessionId);
});

/// Stream danh sách đơn gọi món của một phiên bàn.
final sessionOrdersProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, sessionId) {
  return ref.watch(orderServiceProvider).watchSessionOrders(sessionId);
});

/// Stream danh sách đơn gọi món theo danh sách trạng thái (dành cho hàng đợi pha chế).
final ordersByStatusesProvider =
    StreamProvider.family<List<OrderModel>, List<OrderStatus>>((ref, statuses) {
  return ref.watch(orderServiceProvider).watchAllOrdersByStatuses(statuses);
});

/// Stream danh sách toàn bộ món trong thực đơn.
final menuItemsProvider = StreamProvider<List<MenuItemModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('menuItems')
      .orderBy('name')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => MenuItemModel.fromMap(doc.data(), doc.id))
        .toList();
  });
});

/// Stream danh sách hóa đơn thanh toán trong ngày hôm nay.
final todayPaymentsProvider = StreamProvider<List<PaymentModel>>((ref) {
  return ref.watch(paymentServiceProvider).watchTodayPayments();
});

/// Stream danh sách đơn đặt bàn no-show trong ngày hôm nay.
final todayNoShowsProvider = StreamProvider<List<ReservationModel>>((ref) {
  return ref.watch(reservationServiceProvider).watchTodayNoShows();
});

/// Cấu hình được lưu qua service, không gọi Firestore từ màn hình.
final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());

/// Các phiên bắt đầu trong ngày, không tính collection chứa đơn mang đi.
final todaySessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  return ref.watch(sessionServiceProvider).watchTodaySessions();
});

/// Đọc đặt chỗ để tính đúng thưởng đặt món trước (đặt bàn đơn thuần không có thưởng).
final reservationByIdProvider =
    StreamProvider.family<ReservationModel?, String>((ref, id) {
  return FirebaseFirestore.instance
      .collection('reservations')
      .doc(id)
      .snapshots()
      .map((doc) =>
          doc.exists ? ReservationModel.fromMap(doc.data()!, doc.id) : null);
});
