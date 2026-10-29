import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Trạng thái của màn hình Đặt bàn trước (Reservation Booking).
class ReservationBookingState {
  final DateTime startTime;
  final int partySize;
  final List<TableModel> availableTables;
  final TableModel? selectedTable;
  final List<OrderItemModel> preOrderItems;
  final bool isSearchingTables;
  final bool isSubmitting;
  final String? errorMessage;
  final String? createdReservationId;

  const ReservationBookingState({
    required this.startTime,
    this.partySize = 2,
    this.availableTables = const [],
    this.selectedTable,
    this.preOrderItems = const [],
    this.isSearchingTables = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.createdReservationId,
  });

  /// Tổng tiền các món đặt trước.
  int get preOrderTotal =>
      preOrderItems.fold(0, (sum, item) => sum + item.totalPrice);

  /// Kiểm tra có món đặt trước hay không để nhận điểm thưởng `preOrderBonusPoints`.
  bool get hasPreOrder => preOrderItems.isNotEmpty;

  ReservationBookingState copyWith({
    DateTime? startTime,
    int? partySize,
    List<TableModel>? availableTables,
    TableModel? selectedTable,
    bool clearSelectedTable = false,
    List<OrderItemModel>? preOrderItems,
    bool? isSearchingTables,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? createdReservationId,
    bool clearSuccess = false,
  }) {
    return ReservationBookingState(
      startTime: startTime ?? this.startTime,
      partySize: partySize ?? this.partySize,
      availableTables: availableTables ?? this.availableTables,
      selectedTable: clearSelectedTable ? null : (selectedTable ?? this.selectedTable),
      preOrderItems: preOrderItems ?? this.preOrderItems,
      isSearchingTables: isSearchingTables ?? this.isSearchingTables,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdReservationId: clearSuccess ? null : (createdReservationId ?? this.createdReservationId),
    );
  }
}

/// ViewModel quản lý toàn bộ nghiệp vụ chọn giờ, tìm bàn, đặt món trước (pre-order)
/// và xác nhận đặt bàn thông qua [ReservationService].
class ReservationBookingViewModel extends StateNotifier<ReservationBookingState> {
  final ReservationService _reservationService;

  ReservationBookingViewModel({required ReservationService reservationService})
      : _reservationService = reservationService,
        super(ReservationBookingState(
          startTime: DateTime.now().add(const Duration(hours: 2)),
        ));

  /// Cập nhật thời điểm bắt đầu hẹn dùng bàn.
  void setStartTime(DateTime time) {
    state = state.copyWith(
      startTime: time,
      availableTables: const [],
      clearSelectedTable: true,
      clearError: true,
    );
  }

  /// Cập nhật số lượng khách.
  void setPartySize(int size) {
    state = state.copyWith(
      partySize: size,
      availableTables: const [],
      clearSelectedTable: true,
      clearError: true,
    );
  }

  /// Chọn bàn từ danh sách bàn khả dụng.
  void selectTable(TableModel? table) {
    state = state.copyWith(selectedTable: table);
  }

  /// Tìm danh sách bàn còn trống thỏa mãn số khách và không bị xung đột 5 slot 30 phút.
  Future<void> findAvailableTables() async {
    state = state.copyWith(isSearchingTables: true, clearError: true);
    try {
      final tables = await _reservationService.getAvailableTables(
        startTime: state.startTime,
        partySize: state.partySize,
      );
      state = state.copyWith(
        isSearchingTables: false,
        availableTables: tables,
        selectedTable: tables.isNotEmpty ? tables.first : null,
        errorMessage: tables.isEmpty
            ? 'Không có bàn nào còn trống cho ${state.partySize} khách vào khung giờ này.'
            : null,
      );
    } catch (e) {
      state = state.copyWith(
        isSearchingTables: false,
        errorMessage: 'Lỗi khi kiểm tra bàn trống: $e',
      );
    }
  }

  /// Thêm món vào danh sách đặt trước (kèm tùy chọn và ghi chú).
  void addPreOrderItem(OrderItemModel item) {
    final updated = List<OrderItemModel>.from(state.preOrderItems)..add(item);
    state = state.copyWith(preOrderItems: updated);
  }

  /// Xóa món khỏi danh sách đặt trước theo vị trí index.
  void removePreOrderItem(int index) {
    if (index < 0 || index >= state.preOrderItems.length) return;
    final updated = List<OrderItemModel>.from(state.preOrderItems)..removeAt(index);
    state = state.copyWith(preOrderItems: updated);
  }

  /// Cập nhật số lượng của một món đặt trước.
  void updatePreOrderItemQuantity(int index, int newQty) {
    if (index < 0 || index >= state.preOrderItems.length) return;
    if (newQty <= 0) {
      removePreOrderItem(index);
      return;
    }
    final updated = List<OrderItemModel>.from(state.preOrderItems);
    updated[index] = updated[index].copyWith(qty: newQty);
    state = state.copyWith(preOrderItems: updated);
  }

  /// Làm trống danh sách món đặt trước.
  void clearPreOrderItems() {
    state = state.copyWith(preOrderItems: const []);
  }

  /// Tạo đặt bàn và khóa 5 slot qua ReservationService transaction.
  Future<String?> submitReservation({
    required UserModel user,
    required AppConfig config,
  }) async {
    if (state.selectedTable == null) {
      state = state.copyWith(errorMessage: 'Vui lòng chọn bàn trước khi xác nhận.');
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final draft = ReservationModel(
        id: '',
        customerId: user.id,
        customerName: user.displayName.isNotEmpty ? user.displayName : 'Khách hàng',
        phone: user.phone,
        tableId: state.selectedTable!.id,
        tableName: state.selectedTable!.name,
        partySize: state.partySize,
        startTime: state.startTime,
        endTime: state.startTime.add(Duration(minutes: config.sessionMinutes)),
        holdUntil: state.startTime.add(Duration(minutes: config.reservationHoldMinutes)),
        status: 'confirmed',
        preOrderItems: state.preOrderItems,
        createdAt: DateTime.now(),
      );

      final resId = await _reservationService
          .createReservation(draft)
          .timeout(const Duration(seconds: 10));
      state = state.copyWith(
        isSubmitting: false,
        createdReservationId: resId,
      );
      return resId;
    } catch (e) {
      final msg = e is StateError ? e.message.toString() : e.toString().contains('TimeoutException')
          ? 'Hết thời gian chờ kết nối máy chủ. Vui lòng kiểm tra lại mạng.'
          : e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Đặt bàn không thành công: $msg',
      );
      return null;
    }
  }

  /// Đặt lại form để thực hiện lần đặt mới.
  void reset() {
    state = ReservationBookingState(
      startTime: DateTime.now().add(const Duration(hours: 2)),
    );
  }
}

/// Provider cho ReservationBookingViewModel.
final reservationBookingViewModelProvider =
    StateNotifierProvider.autoDispose<ReservationBookingViewModel, ReservationBookingState>((ref) {
  return ReservationBookingViewModel(
    reservationService: ref.watch(reservationServiceProvider),
  );
});
