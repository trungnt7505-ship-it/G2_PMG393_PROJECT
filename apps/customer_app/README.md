# Ứng Dụng Khách Hàng (Customer App - PRM393)

Ứng dụng Khách hàng thuộc hệ thống **Cafe Table & Order Management System** (Phụ trách: **DƯƠNG BÙI**).
Được thiết kế tối ưu giao diện Mobile dọc, áp dụng kiến trúc chuẩn **MVVM (Model - View - ViewModel) + Repository / Service Pattern**.

---

## 1. Cấu Trúc Thư Mục Chuẩn MVVM

```text
apps/customer_app/lib/
├── firebase_options.dart               # Cấu hình kết nối Firebase client cho project cafe-73637
├── main.dart                           # Khởi tạo Firebase, AlarmService, Theme và Root Widget
├── routing/
│   └── app_router.dart                 # Quản lý danh mục Route và điều hướng màn hình
├── repositories/
│   └── customer_repository.dart        # Tầng trung gian trừu tượng hóa dữ liệu (Session, PointTx, Payments, Orders)
├── viewmodels/
│   ├── auth_viewmodel.dart             # ViewModel xử lý đăng nhập, đăng ký, Google sign-in, reset password
│   ├── home_viewmodel.dart             # ViewModel quản lý bộ lọc danh mục và tìm kiếm thực đơn
│   ├── reservation_booking_viewmodel.dart # ViewModel đặt bàn trước, chọn món preorder và tính điểm thưởng
│   └── active_session_viewmodel.dart   # ViewModel thao tác phiên bàn, gọi phục vụ, tính tiền và giỏ gọi món
├── screens/
│   ├── auth/
│   │   └── customer_auth_screen.dart   # Màn hình đăng nhập/đăng ký tài khoản khách hàng
│   ├── home/
│   │   └── customer_home_screen.dart   # Màn hình chính: Thẻ VIP, Banner bàn đang dùng, Menu trực tiếp
│   ├── reservation/
│   │   ├── reservation_booking_screen.dart # Màn hình đặt bàn trước kèm chọn món (Pre-order)
│   │   └── my_reservations_screen.dart     # Danh sách đặt bàn (Sắp tới & Lịch sử) kèm mã QR check-in
│   ├── scanner/
│   │   └── table_qr_scanner_screen.dart    # Check-in nhận bàn bằng QR bàn (Hỗ trợ phím test 1-chạm)
│   ├── session/
│   │   └── active_session_screen.dart  # Theo dõi phiên bàn, đếm ngược, gia hạn, trả sớm, gọi món
│   └── history/
│       └── points_and_history_screen.dart # Lịch sử biến động điểm (pointTx) và hóa đơn thanh toán
└── widgets/
    ├── active_session_banner.dart      # Banner phiên bàn đang dùng trên trang chủ
    ├── item_options_dialog.dart        # Hộp thoại chọn tùy chọn món (Size, Đá, Đường, Topping)
    └── member_qr_dialog.dart           # Hộp thoại xuất trình mã QR thành viên cafe://member/{uid}
```

---

## 2. Các Chức Năng Đã Hoàn Thiện (Phần B — Dương Bùi)

1. **Xác thực & Tài khoản (`CustomerAuthScreen`):**
   - Đăng nhập bằng Email & Mật khẩu (chặn tài khoản nhân viên không thuộc quyền khách hàng).
   - Đăng ký tài khoản khách hàng mới với `role: customer`, khởi tạo hồ sơ Firestore và điểm thưởng tích lũy.
   - Đăng nhập một chạm bằng Google.
   - Quên mật khẩu & gửi email đặt lại mật khẩu.
   - Giao diện Responsive tự động co giãn giữa Mobile dọc và Tablet/Web.

2. **Trang chủ Khách hàng (`CustomerHomeScreen`):**
   - Thẻ thành viên VIP hiển thị họ tên, số điện thoại, số điểm tích lũy hiện có.
   - Hộp thoại mã QR thành viên `cafe://member/{uid}` để quầy thu ngân quét tích/đổi điểm.
   - **Banner phiên bàn đang dùng (Active Session Banner):** Tự động phát hiện khi khách có phiên hoạt động tại quán, hiển thị đồng hồ đếm ngược và lối tắt vào thẳng phiên bàn.
   - Thực đơn trực tiếp (Live Menu) với bộ lọc danh mục (Cà phê, Trà, Bánh...) và tìm kiếm realtime.

3. **Đặt bàn trước & Món đặt trước (`ReservationBookingScreen`):**
   - Chọn ngày giờ và số khách giới hạn theo cấu hình hệ thống (`minAdvanceMinutes`, `maxAdvanceDays`).
   - Kiểm tra và gợi ý bàn trống qua `ReservationService.getAvailableTables` (chống xung đột 5 slot 30 phút).
   - **Chọn món đặt trước (Pre-order items):** Cho phép chọn món ăn/nước uống, tùy biến options và ghi chú. Đơn đặt có món đặt trước được cộng điểm thưởng `preOrderBonusPoints`.
   - Tạo đơn đặt bàn qua transaction và xuất mã QR đặt trước trực quan `cafe://preorder/{resId}`.

4. **Đơn đặt bàn của tôi (`MyReservationsScreen`):**
   - Phân loại rõ ràng 2 tab: *Sắp tới / Giữ chỗ* và *Lịch sử*.
   - Hiển thị chi tiết bàn, thời gian bắt đầu, hạn giữ chỗ (`holdUntil`), số khách và danh sách món đặt trước.
   - Mã QR hình ảnh sắc nét để xuất trình cho nhân viên quầy quét nhận bàn.
   - Hủy đặt bàn an toàn (tự động giải phóng 5 slot đã khóa).

5. **Check-in nhận bàn tại quán (`TableQrScannerScreen`):**
   - Hỗ trợ dán trực tiếp nội dung mã QR bàn: `cafe://table/{tableId}?k={qrSecret}`.
   - Tích hợp cụm phím thử nghiệm nhanh (Demo 1-chạm: Bàn 01, 02, 03...) giúp chấm thi và test nghiệp vụ mượt mà.
   - Tự động mở phiên và chuyển ngay sang màn hình `ActiveSessionScreen`.

6. **Phiên bàn đang dùng (`ActiveSessionScreen`):**
   - Đồng hồ đếm ngược [CountdownTimerWidget] kết nối [AlarmService] cảnh báo rung/thông báo tại các mốc 15', 5', 0'.
   - **Gia hạn thời gian (+30 phút):** Tăng thời lượng phiên bàn theo cấu hình hệ thống.
   - **Xin trả bàn sớm (Early Release):** Đánh dấu trả bàn sớm để nhận thêm điểm thưởng `earlyReleaseBonusPoints`.
   - **Gọi phục vụ & Yêu cầu hóa đơn:** Gửi request thời gian thực tới nhân viên phục vụ và quầy thu ngân.
   - **Gọi thêm món tại bàn:** Chọn món kèm tùy chọn chi tiết (Single/Multiple choices, ghi chú), quản lý giỏ gọi thêm tạm thời và gửi lên bếp với trạng thái `pending`.
   - Theo dõi tiến độ đơn hàng realtime: `pending` → `confirmed` → `preparing` → `ready` → `served`.

7. **Lịch sử điểm & Hóa đơn (`PointsAndHistoryScreen`):**
   - Xem tổng điểm tích lũy và quy tắc đổi điểm (10.000đ = 1 điểm, đổi tối đa 50% bill).
   - Lịch sử biến động điểm (`pointTx`): Tích lũy (`earn`), Đổi điểm (`redeem`), Thưởng trả sớm (`bonus_early_release`), Thưởng đặt trước (`bonus_preorder`).
   - Danh sách hóa đơn đã thanh toán kèm nút xem lại chi tiết từng món đã dùng.

---

## 3. Kiểm Thử (Unit Test & Widget Test)

Thư mục `test/` gồm đầy đủ các bài kiểm thử theo Mục 7.2 của môn học PRM393:

- `test/countdown_timer_widget_test.dart` (**DUONG BUI**):
  - Hiển thị đúng định dạng `HH:mm:ss` và màu xanh khi còn > 15 phút.
  - Tự động đổi sang màu Cam (`AppColors.statusExpiring`) khi còn <= 15 phút.
  - Hiển thị nút "Gia hạn +30 phút" và kích hoạt callback `onExtend` khi người dùng bấm nút.
  - Đổi sang màu Đỏ (`AppColors.statusOvertime`) và có dấu trừ (`-`) khi phiên quá giờ.
  - Kiểm thử khả năng nhận cấu hình ngưỡng cảnh báo động (`warningMinutes`, `extendStepMinutes`).
- `test/customer_viewmodels_test.dart`:
  - Kiểm thử tính giá món kèm tùy chọn (Size, Topping) và số lượng.
  - Kiểm thử giỏ món đặt trước và cờ `hasPreOrder`.
  - Kiểm thử giỏ gọi thêm tại bàn của phiên đang hoạt động.

### Lệnh chạy kiểm thử:

```bash
flutter test
```

### Lệnh phân tích mã nguồn (Linting):

```bash
flutter analyze
```

### Lệnh khởi chạy ứng dụng:

```bash
flutter run -d chrome
```
hoặc chạy trên thiết bị Android:
```bash
flutter run -d android
```
