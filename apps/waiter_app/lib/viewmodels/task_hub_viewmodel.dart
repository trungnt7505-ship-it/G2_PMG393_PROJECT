import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// ViewModel xử lý Trung tâm Tác vụ [WaiterTaskHubScreen] của Nhân viên Phục vụ:
/// Tab 1: Duyệt đơn pending từ khách tự đặt tại bàn.
/// Tab 2: Món sẵn sàng (ready) chờ nhân viên bưng ra bàn.
/// Tab 3: Yêu cầu từ bàn (call_waiter, request_bill, release_table, early_release).
class TaskHubViewModel extends StateNotifier<AsyncValue<void>> {
  final OrderService _orderService;
  final SessionService _sessionService;

  TaskHubViewModel(this._orderService, this._sessionService)
      : super(const AsyncValue.data(null));

  /// Duyệt đơn gọi món pending từ khách tự đặt.
  Future<bool> approveOrder(String sessionId, String orderId) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();
    try {
      await _orderService.approveOrder(sessionId, orderId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Từ chối đơn gọi món kèm lý do.
  Future<bool> cancelOrder(
    String sessionId,
    String orderId, {
    required String reason,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();
    try {
      await _orderService.cancelOrder(sessionId, orderId, reason: reason);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Cập nhật trạng thái món đã chế biến xong thành đã mang ra bàn (`served`).
  Future<bool> markOrderServed(String sessionId, String orderId) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();
    try {
      await _orderService.updatePreparationStatus(
        sessionId,
        orderId,
        OrderStatus.served,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Đánh dấu đã giải quyết yêu cầu hỗ trợ từ bàn.
  Future<bool> resolveRequest(String requestId) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();
    try {
      await _sessionService.resolveRequest(requestId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Provider cho [TaskHubViewModel].
final taskHubViewModelProvider =
    StateNotifierProvider<TaskHubViewModel, AsyncValue<void>>((ref) {
  final orderService = ref.watch(orderServiceProvider);
  final sessionService = ref.watch(sessionServiceProvider);
  return TaskHubViewModel(orderService, sessionService);
});
