# CAFE TABLE & ORDER MANAGEMENT SYSTEM

Hệ thống quản lý đặt bàn và gọi món thời gian thực dành cho quán Cafe.

## Cấu trúc Monorepo

- `firebase/`: Quy tắc bảo mật Firestore (`firestore.rules`) và cấu hình chỉ mục truy vấn (`firestore.indexes.json`).
- `packages/core/`: Gói thư viện nền tảng dùng chung cho cả 3 ứng dụng:
  - `constants/`: Hằng số nghiệp vụ (`AppConfig`) và các Enum chuẩn (`enums.dart`).
  - `models/`: Mô hình dữ liệu Firestore (User, Table, Slot, Menu, Reservation, Session, Order, Request, Payment).
  - `services/`: Bộ dịch vụ xử lý logic và giao tiếp Firestore (`ClockService`, `AuthService`, `ReservationService`, `SessionService`, `OrderService`, `PaymentService`, `AlarmService`, `SeedService`).
  - `providers/`: State Management với Riverpod Providers dùng chung.
  - `theme/`: Bảng màu chuẩn theo trạng thái bàn (`app_colors.dart`) và chủ đề giao diện (`app_theme.dart`).
  - `widgets/`: Đồng hồ đếm ngược (`CountdownTimerWidget`) và huy hiệu trạng thái (`StatusBadge`).
  - `test/`: 100% Unit Tests kiểm thử hiển thị bàn, tính tiền & điểm thưởng, và sinh khung giờ giữ chỗ (Slots).
- `apps/`:
  - `counter_app/`: Ứng dụng Quầy POS & Quản lý (Trường).
  - `customer_app/`: Ứng dụng Khách hàng (Dương Bùi).
  - `waiter_app/`: Ứng dụng Nhân viên Phục vụ (Trung).
