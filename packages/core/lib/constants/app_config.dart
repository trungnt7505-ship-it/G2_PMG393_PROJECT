/// Cấu hình các hằng số nghiệp vụ của hệ thống Cafe.
/// Được đồng bộ từ document Firestore: `config/app`.
class AppConfig {
  /// Thời lượng tiêu chuẩn cho một phiên dùng bàn (mặc định 120 phút).
  final int sessionMinutes;

  /// Số phút gia hạn mỗi lần khi khách có nhu cầu (mặc định 30 phút).
  final int extendStepMinutes;

  /// Các mốc thời gian cảnh báo trước khi hết giờ (mặc định 15 phút và 5 phút).
  final List<int> warnMinutes;

  /// Thời gian tối đa giữ bàn sau giờ hẹn, quá giờ tự động đánh dấu no_show (mặc định 15 phút).
  final int reservationHoldMinutes;

  /// Khoảng đệm thời gian giữa hai phiên để nhân viên dọn bàn (mặc định 15 phút).
  final int bufferMinutes;

  /// Cho phép khách đến check-in sớm tối đa trước giờ hẹn (mặc định 15 phút).
  final int checkInEarlyMinutes;

  /// Đặt bàn trước tối thiểu (mặc định 30 phút).
  final int minAdvanceMinutes;

  /// Đặt bàn trước tối đa (mặc định 7 ngày).
  final int maxAdvanceDays;

  /// Tỷ lệ tích điểm: số tiền VND để nhận được 1 điểm (mặc định 10.000 VND = 1 điểm).
  final int pointEarnVnd;

  /// Giá trị quy đổi khi tiêu điểm: 1 điểm = số tiền VND giảm giá (mặc định 1 điểm = 1.000 VND).
  final int pointRedeemVnd;

  /// Tỷ lệ giảm giá tối đa bằng điểm trên tổng hóa đơn (mặc định 50%).
  final int maxRedeemPercent;

  /// Thời gian tối thiểu còn lại để được tính là trả bàn sớm (mặc định >= 30 phút).
  final int earlyReleaseMinMinutes;

  /// Số điểm thưởng tặng khách khi chủ động trả bàn sớm hợp lệ (mặc định 20 điểm).
  final int earlyReleaseBonusPoints;

  /// Số điểm thưởng tặng khách khi có đặt món trước qua App (mặc định 10 điểm).
  final int preOrderBonusPoints;

  const AppConfig({
    this.sessionMinutes = 120,
    this.extendStepMinutes = 30,
    this.warnMinutes = const [15, 5],
    this.reservationHoldMinutes = 15,
    this.bufferMinutes = 15,
    this.checkInEarlyMinutes = 15,
    this.minAdvanceMinutes = 30,
    this.maxAdvanceDays = 7,
    this.pointEarnVnd = 10000,
    this.pointRedeemVnd = 1000,
    this.maxRedeemPercent = 50,
    this.earlyReleaseMinMinutes = 30,
    this.earlyReleaseBonusPoints = 20,
    this.preOrderBonusPoints = 10,
  });

  /// Giá trị cấu hình mặc định dùng khi chưa tải được từ Firestore.
  static const AppConfig defaultConfig = AppConfig();

  /// Khởi tạo AppConfig từ Map lấy trên Firestore.
  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      sessionMinutes: map['sessionMinutes'] as int? ?? 120,
      extendStepMinutes: map['extendStepMinutes'] as int? ?? 30,
      warnMinutes: (map['warnMinutes'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [15, 5],
      reservationHoldMinutes: map['reservationHoldMinutes'] as int? ?? 15,
      bufferMinutes: map['bufferMinutes'] as int? ?? 15,
      checkInEarlyMinutes: map['checkInEarlyMinutes'] as int? ?? 15,
      minAdvanceMinutes: map['minAdvanceMinutes'] as int? ?? 30,
      maxAdvanceDays: map['maxAdvanceDays'] as int? ?? 7,
      pointEarnVnd: map['pointEarnVnd'] as int? ?? 10000,
      pointRedeemVnd: map['pointRedeemVnd'] as int? ?? 1000,
      maxRedeemPercent: map['maxRedeemPercent'] as int? ?? 50,
      earlyReleaseMinMinutes: map['earlyReleaseMinMinutes'] as int? ?? 30,
      earlyReleaseBonusPoints: map['earlyReleaseBonusPoints'] as int? ?? 20,
      preOrderBonusPoints: map['preOrderBonusPoints'] as int? ?? 10,
    );
  }

  /// Chuyển đối tượng thành Map để lưu trữ trên Firestore.
  Map<String, dynamic> toMap() {
    return {
      'sessionMinutes': sessionMinutes,
      'extendStepMinutes': extendStepMinutes,
      'warnMinutes': warnMinutes,
      'reservationHoldMinutes': reservationHoldMinutes,
      'bufferMinutes': bufferMinutes,
      'checkInEarlyMinutes': checkInEarlyMinutes,
      'minAdvanceMinutes': minAdvanceMinutes,
      'maxAdvanceDays': maxAdvanceDays,
      'pointEarnVnd': pointEarnVnd,
      'pointRedeemVnd': pointRedeemVnd,
      'maxRedeemPercent': maxRedeemPercent,
      'earlyReleaseMinMinutes': earlyReleaseMinMinutes,
      'earlyReleaseBonusPoints': earlyReleaseBonusPoints,
      'preOrderBonusPoints': preOrderBonusPoints,
    };
  }

  /// Tạo bản sao có sửa đổi thuộc tính.
  AppConfig copyWith({
    int? sessionMinutes,
    int? extendStepMinutes,
    List<int>? warnMinutes,
    int? reservationHoldMinutes,
    int? bufferMinutes,
    int? checkInEarlyMinutes,
    int? minAdvanceMinutes,
    int? maxAdvanceDays,
    int? pointEarnVnd,
    int? pointRedeemVnd,
    int? maxRedeemPercent,
    int? earlyReleaseMinMinutes,
    int? earlyReleaseBonusPoints,
    int? preOrderBonusPoints,
  }) {
    return AppConfig(
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      extendStepMinutes: extendStepMinutes ?? this.extendStepMinutes,
      warnMinutes: warnMinutes ?? this.warnMinutes,
      reservationHoldMinutes:
          reservationHoldMinutes ?? this.reservationHoldMinutes,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      checkInEarlyMinutes: checkInEarlyMinutes ?? this.checkInEarlyMinutes,
      minAdvanceMinutes: minAdvanceMinutes ?? this.minAdvanceMinutes,
      maxAdvanceDays: maxAdvanceDays ?? this.maxAdvanceDays,
      pointEarnVnd: pointEarnVnd ?? this.pointEarnVnd,
      pointRedeemVnd: pointRedeemVnd ?? this.pointRedeemVnd,
      maxRedeemPercent: maxRedeemPercent ?? this.maxRedeemPercent,
      earlyReleaseMinMinutes:
          earlyReleaseMinMinutes ?? this.earlyReleaseMinMinutes,
      earlyReleaseBonusPoints:
          earlyReleaseBonusPoints ?? this.earlyReleaseBonusPoints,
      preOrderBonusPoints: preOrderBonusPoints ?? this.preOrderBonusPoints,
    );
  }
}

