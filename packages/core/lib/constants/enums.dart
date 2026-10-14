/// Vai trò của người dùng trong hệ thống Cafe.
enum UserRole {
  customer,
  waiter,
  counter,
  manager;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.customer,
    );
  }
}

/// Trạng thái vật lý thực tế của bàn được lưu trên Firestore (`tables/{tableId}.status`).
enum TablePhysicalStatus {
  available,
  occupied,
  needs_cleaning;

  static TablePhysicalStatus fromString(String? value) {
    return TablePhysicalStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TablePhysicalStatus.available,
    );
  }
}

/// Trạng thái hiển thị giao diện của bàn (được tính toán động trên Client).
/// Gồm 6 trạng thái:
/// - [free]: Bàn trống, chưa có khách.
/// - [reservedSoon]: Sắp có khách đặt hẹn tới (trong vòng 30 phút).
/// - [using]: Bàn đang có khách sử dụng bình thường.
/// - [expiring]: Bàn sắp hết thời lượng phiên (còn <= 15 phút).
/// - [overtime]: Bàn đã quá thời lượng quy định (quá giờ).
/// - [cleaning]: Bàn khách đã thanh toán, đang chờ nhân viên dọn dẹp.
enum TableDisplayStatus {
  free,
  reservedSoon,
  using,
  expiring,
  overtime,
  cleaning;

  static TableDisplayStatus fromString(String? value) {
    return TableDisplayStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TableDisplayStatus.free,
    );
  }
}

/// Trạng thái của đơn đặt bàn trước (`reservations/{resId}.status`).
enum ReservationStatus {
  confirmed,
  checked_in,
  no_show,
  cancelled,
  completed;

  static ReservationStatus fromString(String? value) {
    return ReservationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReservationStatus.confirmed,
    );
  }
}

/// Trạng thái của phiên sử dụng bàn (`sessions/{sessionId}.status`).
enum SessionStatus {
  active,
  billing,
  paid,
  cancelled;

  static SessionStatus fromString(String? value) {
    return SessionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SessionStatus.active,
    );
  }
}

/// Trạng thái chế biến/phục vụ của một đơn gọi món (`orders/{orderId}.status`).
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  served,
  cancelled;

  static OrderStatus fromString(String? value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// Hình thức gọi món: Dùng tại bàn hay Mang về.
enum OrderType {
  dine_in,
  takeaway;

  static OrderType fromString(String? value) {
    return OrderType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OrderType.dine_in,
    );
  }
}

/// Loại yêu cầu hỗ trợ gửi từ bàn đến nhân viên phục vụ (`requests/{reqId}.type`).
enum RequestType {
  call_waiter,
  request_bill,
  release_table,
  early_release;

  static RequestType fromString(String? value) {
    return RequestType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RequestType.call_waiter,
    );
  }
}

/// Phương thức thanh toán hóa đơn (`payments/{payId}.method`).
enum PaymentMethod {
  cash,
  qr,
  card;

  static PaymentMethod fromString(String? value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

