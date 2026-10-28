import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import '../repositories/customer_repository.dart';

/// Trạng thái của màn hình phiên đang dùng (Active Session).
class ActiveSessionState {
  final bool isActionLoading;
  final String? actionError;
  final String? actionSuccess;
  final List<OrderItemModel> draftCart;

  const ActiveSessionState({
    this.isActionLoading = false,
    this.actionError,
    this.actionSuccess,
    this.draftCart = const [],
  });

  /// Tổng tiền các món đang nằm trong giỏ gọi thêm tạm thời.
  int get draftCartTotal =>
      draftCart.fold(0, (sum, item) => sum + item.totalPrice);

  ActiveSessionState copyWith({
    bool? isActionLoading,
    String? actionError,
    String? actionSuccess,
    bool clearMessages = false,
    List<OrderItemModel>? draftCart,
  }) {
    return ActiveSessionState(
      isActionLoading: isActionLoading ?? this.isActionLoading,
      actionError: clearMessages ? null : (actionError ?? this.actionError),
      actionSuccess: clearMessages ? null : (actionSuccess ?? this.actionSuccess),
      draftCart: draftCart ?? this.draftCart,
    );
  }
}

/// ViewModel quản lý các tương tác trong phiên bàn của khách hàng:
/// - Gia hạn thời gian bàn
/// - Yêu cầu trả bàn sớm để nhận điểm thưởng
/// - Gửi yêu cầu gọi phục vụ / yêu cầu tính tiền
/// - Quản lý giỏ món gọi thêm (draft cart) kèm các tùy chọn (options) và gửi đơn.
class ActiveSessionViewModel extends StateNotifier<ActiveSessionState> {
  final CustomerRepository _repository;

  ActiveSessionViewModel({required CustomerRepository repository})
      : _repository = repository,
        super(const ActiveSessionState());

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  /// Thêm một món kèm tùy chọn vào giỏ món gọi thêm.
  void addToDraftCart(OrderItemModel item) {
    final updated = List<OrderItemModel>.from(state.draftCart)..add(item);
    state = state.copyWith(draftCart: updated, clearMessages: true);
  }

  /// Xóa món khỏi giỏ gọi thêm theo index.
  void removeFromDraftCart(int index) {
    if (index < 0 || index >= state.draftCart.length) return;
    final updated = List<OrderItemModel>.from(state.draftCart)..removeAt(index);
    state = state.copyWith(draftCart: updated, clearMessages: true);
  }

  /// Cập nhật số lượng của một món trong giỏ gọi thêm.
  void updateDraftCartQuantity(int index, int newQty) {
    if (index < 0 || index >= state.draftCart.length) return;
    if (newQty <= 0) {
      removeFromDraftCart(index);
      return;
    }
    final updated = List<OrderItemModel>.from(state.draftCart);
    updated[index] = updated[index].copyWith(qty: newQty);
    state = state.copyWith(draftCart: updated, clearMessages: true);
  }

  /// Xóa toàn bộ giỏ gọi thêm.
  void clearDraftCart() {
    state = state.copyWith(draftCart: const [], clearMessages: true);
  }

  /// Gửi toàn bộ danh sách món trong giỏ lên bếp (trạng thái 'pending').
  Future<bool> submitDraftCart({
    required String sessionId,
    required String tableId,
    required String tableName,
    required String uid,
  }) async {
    if (state.draftCart.isEmpty) return false;

    state = state.copyWith(isActionLoading: true, clearMessages: true);
    try {
      await _repository.submitOrder(
        sessionId: sessionId,
        tableId: tableId,
        tableName: tableName,
        items: state.draftCart,
        createdBy: uid,
      );
      state = state.copyWith(
        isActionLoading: false,
        draftCart: const [],
        actionSuccess: 'Đã gửi ${state.draftCart.length} món thành công! Vui lòng chờ nhân viên xác nhận.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Không thể gửi đơn món: $e',
      );
      return false;
    }
  }

  /// Gia hạn phiên bàn hiện tại (+30 phút hoặc tối đa tới lịch hẹn tiếp theo).
  Future<bool> extendSession(String sessionId, String uid) async {
    state = state.copyWith(isActionLoading: true, clearMessages: true);
    try {
      final addedMinutes =
          await _repository.extendSession(sessionId, byUid: uid);
      state = state.copyWith(
        isActionLoading: false,
        actionSuccess: 'Gia hạn thành công thêm $addedMinutes phút!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Không thể gia hạn: $e',
      );
      return false;
    }
  }

  /// Gửi yêu cầu xin trả bàn sớm để nhận điểm thưởng `earlyReleaseBonusPoints`.
  Future<bool> requestEarlyRelease(String sessionId, String uid) async {
    state = state.copyWith(isActionLoading: true, clearMessages: true);
    try {
      await _repository.requestEarlyRelease(sessionId, customerId: uid);
      state = state.copyWith(
        isActionLoading: false,
        actionSuccess:
            'Đã gửi yêu cầu trả bàn sớm thành công! Bạn sẽ nhận thêm điểm thưởng khi thanh toán.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Không thể xin trả bàn sớm: $e',
      );
      return false;
    }
  }

  /// Gửi yêu cầu gọi nhân viên phục vụ tới bàn.
  Future<bool> callWaiter({
    required String sessionId,
    required String tableId,
    required String tableName,
    required String uid,
    String note = '',
  }) async {
    state = state.copyWith(isActionLoading: true, clearMessages: true);
    try {
      await _repository.sendTableRequest(
        sessionId: sessionId,
        tableId: tableId,
        tableName: tableName,
        type: RequestType.call_waiter,
        createdBy: uid,
        message: note.isNotEmpty ? note : 'Khách yêu cầu hỗ trợ tại bàn',
      );
      state = state.copyWith(
        isActionLoading: false,
        actionSuccess: 'Đã gọi nhân viên phục vụ! Nhân viên sẽ tới bàn ngay.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Không gửi được yêu cầu gọi phục vụ: $e',
      );
      return false;
    }
  }

  /// Gửi yêu cầu thanh toán / xuất hóa đơn tới quầy thu ngân.
  Future<bool> requestBill({
    required String sessionId,
    required String tableId,
    required String tableName,
    required String uid,
  }) async {
    state = state.copyWith(isActionLoading: true, clearMessages: true);
    try {
      await _repository.sendTableRequest(
        sessionId: sessionId,
        tableId: tableId,
        tableName: tableName,
        type: RequestType.request_bill,
        createdBy: uid,
        message: 'Khách yêu cầu thanh toán hóa đơn',
      );
      state = state.copyWith(
        isActionLoading: false,
        actionSuccess: 'Đã gửi yêu cầu tính tiền! Thu ngân đang chuẩn bị hóa đơn cho bạn.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Không gửi được yêu cầu tính tiền: $e',
      );
      return false;
    }
  }
}

/// Provider cho ActiveSessionViewModel.
final activeSessionViewModelProvider =
    StateNotifierProvider.autoDispose<ActiveSessionViewModel, ActiveSessionState>((ref) {
  return ActiveSessionViewModel(
    repository: ref.watch(customerRepositoryProvider),
  );
});
