# Dữ liệu demo tích hợp ba app

Project: `cafe-73637`. Batch: `demo_team_20261018_v1`. Tạo lúc 17:44 18/10/26 (Asia/Saigon).

Dữ liệu mẫu được lưu trên Firestore thật, dùng chung giữa ba app. Không sửa 12 bàn cũ hoặc thực đơn/config. Khu mới: **Demo tích hợp**. Các thao tác thử sẽ thay đổi dữ liệu demo và thống kê.

## Tài khoản

| Email | Vai trò | Tình huống |
|---|---|---|
| demo.customer.an@example.com | customer | Khách Demo An — demo_team_customer_an |
| demo.customer.binh@example.com | customer | Khách Demo Bình — demo_team_customer_binh |
| demo.customer.chi@example.com | customer | Khách Demo Chi — demo_team_customer_chi |
| demo.customer.dung@example.com | customer | Khách Demo Dũng — demo_team_customer_dung |
| demo.waiter@example.com | waiter | Phục vụ Demo — demo_team_waiter |

Mật khẩu được cung cấp riêng trong chat, không lưu trong Git. Đăng nhập bằng Firebase Authentication và hồ sơ users có cùng UID. Nếu app vẫn dùng cấu hình Firebase mẫu thì cần đăng ký/cấu hình app đó vào project cafe-73637 trước khi đăng nhập.

## Bàn và tình huống

| ID bàn | Tình huống lúc tạo |
|---|---|
| demo_team_using | Demo 01 • Đang dùng |
| demo_team_expiring | Demo 02 • Sắp hết giờ |
| demo_team_overtime | Demo 03 • Quá giờ |
| demo_team_billing | Demo 04 • Chờ thanh toán |
| demo_team_cleaning | Demo 05 • Chờ dọn |
| demo_team_reserved | Demo 06 • Đặt trước |
| demo_team_free | Demo 07 • Bàn trống |

An: phiên đang dùng, có đơn served, pending và cancelled. Bình: phiên sắp hết giờ, có đơn confirmed và preparing. Bàn quá giờ có đơn ready. Bàn chờ thanh toán có đơn served và request_bill. Dũng: có hóa đơn lịch sử và điểm tích lũy tương ứng.

## Đặt bàn và QR

- demo_team_preorder: Chi đặt bàn demo_team_reserved lúc 18:00 18/10/26, có món đặt trước. QR: cafe://preorder/demo_team_preorder.
- demo_team_tomorrow: Dũng đặt bàn demo_team_free lúc 18:00 19/10/26, không đặt món trước.
- demo_team_checked_in: An đã nhận bàn, liên kết demo_team_using.
- demo_team_cancelled, demo_team_no_show, demo_team_completed: lịch sử tương ứng.
- QR thành viên: cafe://member/{uid}. QR bàn: lấy tableId và qrSecret từ document tables tương ứng.

## Lưu ý cho người phát triển

- Tên collection, field và trạng thái theo PROJECT_SPEC.md và các model trong packages/core. Gọi AuthService/ReservationService/SessionService/OrderService/PaymentService hoặc provider; không ghi Firestore trực tiếp từ UI.
- Thời gian đang dùng/sắp hết/quá giờ được tính tương đối tại lúc tạo. Sau một thời gian chúng tự chuyển trạng thái; đặt chỗ cũng có thể quá hạn. Đây không phải dữ liệu luôn tự làm mới.
- Bản ghi đều có demoBatch để nhận diện. Không tự xóa hoặc reset dữ liệu đang được người khác thao tác.
- Một hóa đơn lịch sử mẫu hôm nay sẽ cộng vào doanh thu/số hóa đơn. Các phiên demo cũng xuất hiện trong thống kê số phiên.
- Không có script tự chạy lại hoặc tự reset. Cần kiểm tra trước nếu muốn nạp lại.
