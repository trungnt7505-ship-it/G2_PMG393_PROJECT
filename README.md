# HỆ THỐNG QUẢN LÝ BÀN VÀ ĐẶT MÓN THỜI GIAN THỰC (G2 CAFE)

> **Dự án đồ án chuyên ngành Cafe Table & Order Management System**  
> Kiến trúc Monorepo xây dựng trên nền tảng **Flutter (Dart 3.x)**, **Cloud Firestore** và **Firebase Authentication**.

---

## 1. BÀI TOÁN & GIẢI PHÁP HỆ THỐNG

Hệ thống tập trung giải quyết 2 bài toán nhức nhối nhất trong vận hành quán Cafe hiện đại:

1. **Rút ngắn thời gian đặt món & thanh toán:**
   - Khách đặt bàn & đặt món trước từ xa qua App (Pre-order), tạo mã QR 1 chạm để quầy POS quét nhận bàn tức thì.
   - Nhân viên phục vụ có thể chọn nhanh tùy chọn món (Đường, Đá, Size, Topping) bằng 1 tay trên điện thoại di động.
   - Quét mã QR thành viên để tích điểm tự động (10.000đ = 1 điểm) và đổi điểm giảm giá hóa đơn (tối đa 50%).

2. **Xoay vòng bàn hiệu quả & Nhắc nhở ngồi lâu:**
   - Mặc định mỗi phiên ngồi tối đa **120 phút**.
   - Đồng hồ đếm ngược đồng bộ theo giờ Server Firestore (`ClockService.serverNow`), ngăn chặn việc gian lận bằng cách chỉnh giờ máy.
   - Cảnh báo âm thanh & rung đổi màu theo 6 trạng thái thời gian thực: Bàn trống (Xanh lá) ➔ Sắp có khách (Vàng nhạt) ➔ Đang dùng (Xanh dương) ➔ Sắp hết giờ (Cam, ≤15 phút) ➔ Quá giờ (Đỏ, >120 phút) ➔ Chờ dọn (Tím).
   - Hỗ trợ gia hạn thêm thời gian (+30 phút) nếu không trùng lịch đặt trước của khách sau.
   - Tặng điểm thưởng khích lệ (+20 điểm) cho khách chủ động báo trả bàn sớm trước 30 phút.

---

## 2. KIẾN TRÚC MONOREPO & PHÂN CHIA VAI TRÒ

Dự án áp dụng mô hình **Monorepo** chia tách rõ ràng giữa Core Platform dùng chung và 3 ứng dụng theo từng nhóm người dùng:

```text
Project_PRM/
├── firebase/                         # Cấu hình bảo mật Cloud Firestore
│   ├── firestore.rules               # Phân quyền 2 lớp (RBAC, chống gian lận dữ liệu)
│   ├── firestore.indexes.json        # Chỉ mục tối ưu truy vấn thời gian thực
│   └── functions/                    # Worker gửi Push Notification qua FCM
├── packages/
│   └── core/                         # GÓI DÙNG CHUNG CHO CẢ 3 APP
│       ├── constants/                # AppConfig (tham số động), Enums trạng thái
│       ├── models/                   # User, Table, Slot, Menu, Reservation, Session, Order, Payment
│       ├── services/                 # ClockService, AuthService, SessionService, PaymentService...
│       ├── providers/                # Riverpod Providers lắng nghe Firestore Realtime Streams
│       ├── theme/                    # AppColors (bảng màu chuẩn theo trạng thái), AppTheme
│       └── widgets/                  # CountdownTimerWidget, StatusBadge dùng chung
└── apps/
    ├── counter_app/                  # [TRƯỜNG] Ứng dụng Quầy POS, Thu ngân & Quản trị doanh thu
    ├── customer_app/                 # [DƯƠNG]  Ứng dụng Khách hàng (Đặt bàn, Gọi món, Tích điểm)
    └── waiter_app/                   # [TRUNG]  Ứng dụng Phục vụ (Sơ đồ bàn, Đặt món tại bàn, Dọn bàn)
```

### Luồng kiến trúc dữ liệu (Clean Architecture + MVVM)
```text
[UI Screen / Dialog] 
         │ (watch / read)
         ▼
[Riverpod ViewModel / StateNotifier]
         │ (call methods)
         ▼
[Core Services (packages/core/services)]
         │ (read/write & stream)
         ▼
[Cloud Firestore Realtime + Firestore Security Rules]
```

---

## 3. TÀI KHOẢN DÙNG THỬ & KỊCH BẢN KIỂM THỬ DEMO

Hệ thống đã nạp sẵn dữ liệu mẫu thực tế trên Firebase (Project: `cafe-73637`):

| Ứng dụng | Email Demo | Vai trò | Màn hình chính |
|---|---|---|---|
| **counter_app** | `demo.flow.20261029.counter@example.com` | `counter`, `manager` | Sơ đồ bàn POS, Hàng đợi đơn, Báo cáo doanh thu |
| **waiter_app** | `waiter.laptop.20261026@example.com` | `waiter` | Sơ đồ bàn trực quan, Đặt món 1 tay, Task Hub |
| **customer_app** | `demo.customer.an@example.com` | `customer` | Thẻ thành viên, Đặt trước kèm món, Đồng hồ đếm ngược |
| **customer_app** | `demo.customer.binh@example.com` | `customer` | Khách đang có phiên bàn sắp hết giờ (≤15 phút) |

*(Mật khẩu mặc định của tất cả các tài khoản demo được cung cấp trong tài liệu bảo vệ).*

---

## 4. HƯỚNG DẪN KHỞI CHẠY HỆ THỐNG

### Cách 1: Chạy nhanh trên Trình duyệt Web (Chrome)
Mở 3 cửa sổ Terminal riêng biệt tại thư mục gốc của dự án:

```powershell
# Cửa sổ 1: Quầy POS / Thu ngân (Cổng 5201)
cd apps/counter_app
flutter run -d chrome --web-port 5201

# Cửa sổ 2: Nhân viên Phục vụ (Cổng 5202)
cd apps/waiter_app
flutter run -d chrome --web-port 5202

# Cửa sổ 3: Khách hàng (Cổng 5203)
cd apps/customer_app
flutter run -d chrome --web-port 5203
```

### Cách 2: Chạy trên Thiết bị di động / Giả lập Android
```powershell
# Chạy ứng dụng Khách hàng hoặc Phục vụ trên máy ảo Android
cd apps/customer_app
flutter run -d android
```

---

## 5. BỘ KIỂM THỬ TỰ ĐỘNG (104 TEST CASES)

Dự án đạt chuẩn kiểm thử tự động với **104/104 tests pass 100%**:
- `packages/core`: **51 tests** (Kiểm tra thuật toán sinh Slot 30 phút, đồng bộ giờ Server, tính tiền & điểm thưởng, quy tắc hủy phiên, bảo mật chống trùng lịch).
- `apps/counter_app`: **31 tests** (Kiểm tra phân quyền Admin, tính toán doanh thu theo mốc thời gian, giới hạn đổi điểm 50%, POS đa kích thước màn hình).
- `apps/customer_app`: **13 tests** (Kiểm tra cập nhật thông tin cá nhân, đồng hồ đổi màu cảnh báo, ẩn đồng hồ khi đã thanh toán).
- `apps/waiter_app`: **9 tests** (Kiểm tra hiển thị sơ đồ bàn theo trạng thái, khả năng thích ứng màn hình laptop/tablet, xử lý mất kết nối).

### Lệnh chạy kiểm thử:
```powershell
# Kiểm thử gói Core
cd packages/core; flutter test

# Kiểm thử 3 ứng dụng
cd apps/counter_app; flutter test
cd apps/customer_app; flutter test
cd apps/waiter_app; flutter test
```

---

## 6. QUY TẮC BẢO MẬT & CHUẨN MÃ NGUỒN

- **Không gọi Firestore trực tiếp ở UI:** Toàn bộ thao tác truy vấn và cập nhật dữ liệu đều thông qua các lớp Service của `packages/core`.
- **Phân quyền 2 lớp (`firestore.rules`):** Khách hàng không thể tự ý sửa đổi `expiresAt` để gia hạn, không thể tự thanh toán hóa đơn, không thể đổi quá 50% tiền bằng điểm.
- **Null Safety & Clean Lints:** Toàn bộ dự án tuân thủ nghiêm ngặt chuẩn `flutter_lints` với **0 errors, 0 warnings**.
