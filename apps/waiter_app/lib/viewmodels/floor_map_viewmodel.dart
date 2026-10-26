import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Trạng thái quản lý Sơ đồ bàn cho Nhân viên Phục vụ.
class FloorMapState {
  final DateTime now;
  final String selectedZone;
  final bool isLoading;
  final String? errorMessage;

  const FloorMapState({
    required this.now,
    this.selectedZone = 'Tất cả',
    this.isLoading = false,
    this.errorMessage,
  });

  FloorMapState copyWith({
    DateTime? now,
    String? selectedZone,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FloorMapState(
      now: now ?? this.now,
      selectedZone: selectedZone ?? this.selectedZone,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ViewModel điều khiển sơ đồ bàn, đồng bộ đếm ngược theo thời gian thực và kích hoạt các tác vụ thao tác bàn.
class FloorMapViewModel extends StateNotifier<FloorMapState> {
  final SessionService _sessionService;
  final AlarmService _alarmService;
  Timer? _tickerTimer;

  FloorMapViewModel(this._sessionService, this._alarmService)
      : super(FloorMapState(now: ClockService.instance.serverNow)) {
    _startTicker();
  }

  /// Khởi tạo Timer cập nhật thời gian máy chủ mỗi 1 giây để đồng bộ đồng hồ đếm ngược.
  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(now: ClockService.instance.serverNow);
    });
  }

  /// Đổi khu vực (Zone) lọc bàn hiển thị.
  void setZone(String zone) {
    state = state.copyWith(selectedZone: zone);
  }

  /// Lắng nghe các phiên hoạt động để kiểm tra và phát âm thanh/rung cảnh báo khi chạm mốc.
  void checkAlarms(List<SessionModel> activeSessions, AppConfig config) {
    _alarmService.onTickCheck(activeSessions, config: config);
  }

  /// Mở bàn mới cho khách vãng lai.
  Future<String?> openSessionForWalkIn({
    required String tableId,
    required String openedBy,
    required String openedByRole,
    String customerName = 'Khách vãng lai',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final sessionId = await _sessionService.openSession(
        tableId: tableId,
        openedBy: openedBy,
        openedByRole: openedByRole,
        customerName: customerName,
      );
      state = state.copyWith(isLoading: false);
      return sessionId;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  /// Check-in hộ khách đặt trước dựa trên reservationId.
  Future<String?> checkInReservation({
    required String reservationId,
    required String tableId,
    required String openedBy,
    required String openedByRole,
    required String customerName,
    String? customerId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final sessionId = await _sessionService.openSession(
        tableId: tableId,
        openedBy: openedBy,
        openedByRole: openedByRole,
        customerName: customerName,
        customerId: customerId,
        reservationId: reservationId,
      );
      state = state.copyWith(isLoading: false);
      return sessionId;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  /// Gia hạn phiên ngồi thêm 30 phút.
  Future<bool> extendSession(String sessionId, String waiterUid) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _sessionService.extendSession(sessionId, byUid: waiterUid);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Chuyển phiên từ bàn hiện tại sang bàn mới.
  Future<bool> switchTable({
    required String sessionId,
    required String newTableId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _sessionService.switchTable(
        sessionId: sessionId,
        newTableId: newTableId,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Gửi yêu cầu nhả bàn (release_table) đến khách hàng.
  Future<bool> sendReleaseTableRequest({
    required String sessionId,
    required String tableId,
    required String tableName,
    required String createdBy,
    String message = 'Bàn đã hết thời lượng sử dụng hoặc sắp tới giờ khách đặt tiếp theo. Xin quý khách vui lòng thanh toán hoặc nhả bàn.',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _sessionService.sendTableRequest(
        sessionId: sessionId,
        tableId: tableId,
        tableName: tableName,
        type: RequestType.release_table,
        createdBy: createdBy,
        message: message,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Hủy phiên mở nhầm của bàn.
  Future<bool> cancelMistakenSession(String sessionId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _sessionService.cancelMistakenSession(sessionId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Xóa trạng thái chờ dọn, chuyển bàn về Bàn trống.
  Future<bool> markTableCleaned(String tableId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _sessionService.markTableCleaned(tableId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }
}

/// Provider cho [FloorMapViewModel].
final floorMapViewModelProvider =
    StateNotifierProvider<FloorMapViewModel, FloorMapState>((ref) {
  final sessionService = ref.watch(sessionServiceProvider);
  final alarmService = ref.watch(alarmServiceProvider);
  return FloorMapViewModel(sessionService, alarmService);
});
