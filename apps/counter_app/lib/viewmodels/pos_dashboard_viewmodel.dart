import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Trạng thái của màn hình POS Dashboard.
class PosDashboardState {
  final String? selectedTableId;
  final String selectedZone;
  final String orderFilter;
  final bool isActionLoading;
  final String? actionMessage;

  const PosDashboardState({
    this.selectedTableId,
    this.selectedZone = 'Tất cả',
    this.orderFilter = 'Tất cả',
    this.isActionLoading = false,
    this.actionMessage,
  });

  PosDashboardState copyWith({
    String? selectedTableId,
    String? selectedZone,
    String? orderFilter,
    bool? isActionLoading,
    String? actionMessage,
  }) {
    return PosDashboardState(
      selectedTableId: selectedTableId ?? this.selectedTableId,
      selectedZone: selectedZone ?? this.selectedZone,
      orderFilter: orderFilter ?? this.orderFilter,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      actionMessage: actionMessage,
    );
  }
}

/// ViewModel quản lý luồng dữ liệu 3 cột trên POS Dashboard.
class PosDashboardViewModel extends StateNotifier<PosDashboardState> {
  final SessionService _sessionService;
  final OrderService _orderService;

  PosDashboardViewModel({
    required SessionService sessionService,
    required OrderService orderService,
  })  : _sessionService = sessionService,
        _orderService = orderService,
        super(const PosDashboardState());

  /// Chọn bàn để hiển thị chi tiết hóa đơn ở Cột 3.
  void selectTable(String? tableId) {
    state = state.copyWith(selectedTableId: tableId);
  }

  /// Lọc sơ đồ bàn theo khu vực (Tầng 1, Tầng 2, Tất cả).
  void filterZone(String zone) {
    state = state.copyWith(selectedZone: zone);
  }

  /// Lọc hàng đợi món (Tất cả, Chờ duyệt, Pha chế, Sẵn sàng).
  void filterOrder(String filter) {
    state = state.copyWith(orderFilter: filter);
  }

  /// Thu ngân duyệt đơn gọi món từ trạng thái `pending` sang `confirmed`.
  Future<void> approveOrder(String sessionId, String orderId) async {
    state = state.copyWith(isActionLoading: true);
    try {
      await _orderService.approveOrder(sessionId, orderId);
      state = state.copyWith(isActionLoading: false, actionMessage: 'Đã duyệt đơn hàng thành công');
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionMessage: 'Lỗi: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  /// Từ chối / Hủy đơn gọi món kèm theo lý do.
  Future<void> cancelOrder(String sessionId, String orderId, String reason) async {
    state = state.copyWith(isActionLoading: true);
    try {
      await _orderService.cancelOrder(sessionId, orderId, reason: reason);
      state = state.copyWith(isActionLoading: false, actionMessage: 'Đã từ chối đơn hàng');
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionMessage: 'Lỗi: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  /// Cập nhật tiến độ pha chế / phục vụ món.
  Future<void> updatePreparationStatus(
    String sessionId,
    String orderId,
    OrderStatus newStatus,
  ) async {
    state = state.copyWith(isActionLoading: true);
    try {
      await _orderService.updatePreparationStatus(sessionId, orderId, newStatus);
      state = state.copyWith(isActionLoading: false);
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionMessage: 'Lỗi: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  /// Đánh dấu yêu cầu từ bàn đã xử lý xong.
  Future<void> resolveRequest(String requestId) async {
    state = state.copyWith(isActionLoading: true);
    try {
      await _sessionService.resolveRequest(requestId);
      state = state.copyWith(isActionLoading: false, actionMessage: 'Đã xử lý yêu cầu');
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionMessage: 'Lỗi: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }
}

/// Provider cho PosDashboardViewModel.
final posDashboardViewModelProvider =
    StateNotifierProvider<PosDashboardViewModel, PosDashboardState>((ref) {
  final sessionService = ref.watch(sessionServiceProvider);
  final orderService = ref.watch(orderServiceProvider);

  return PosDashboardViewModel(
    sessionService: sessionService,
    orderService: orderService,
  );
});
