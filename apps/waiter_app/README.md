# Waiter App — demo trên laptop

Dùng trình duyệt Chrome/Edge, kết nối Firebase project `cafe-73637` và Firestore `(default)` giống counter. Không cần tạo database mới, máy in hoặc camera để dùng các chức năng chính.

## Chạy trên Windows

Tại thư mục gốc repository:

```powershell
cd apps/waiter_app
flutter pub get
flutter run -d chrome --web-port 5202
```

Chạy counter ở terminal riêng, cổng khác:

```powershell
cd apps/counter_app
flutter pub get
flutter run -d chrome --web-port 5201
```

Mỗi laptop có thể chạy app của mình tại localhost. Dữ liệu đồng bộ qua Internet/Firestore, không cần dùng chung địa chỉ localhost. Giữ hai app ở hai cổng khác nhau khi chạy cùng máy để tách phiên đăng nhập. Nếu mở trên máy khác qua mạng LAN, cần cấu hình host/firewall/authorized domains phù hợp; quy trình mặc định là chạy localhost trên từng máy.

## Đăng nhập

- Dùng tài khoản Firebase Authentication thật, có document `users/{uid}` cùng UID và role `waiter`, `counter` hoặc `manager`.
- Email demo được điền sẵn là `demo.waiter@example.com`; nhập mật khẩu đã được cấp riêng. Không lưu mật khẩu trong Git.
- Đăng nhập lỗi chỉ hiện lỗi, không tự tạo tài khoản, không dùng anonymous và không tự đổi role. Khách có phiên đăng nhập cũ bị chặn khỏi màn hình phục vụ.
- Lỗi khởi tạo Firebase có nút thử lại. Lỗi dữ liệu trên sơ đồ có nút tải lại; cần kiểm tra mạng, Auth, Rules/Indexes nếu bị từ chối.

## Luồng demo với counter

1. Đăng nhập waiter và counter bằng tài khoản đúng vai trò.
2. Waiter chọn bàn trống → mở bàn khách vãng lai; counter kiểm tra bàn cập nhật. Lịch đặt thật còn hiệu lực có thể check-in từ danh sách, không cần QR/camera.
3. Waiter mở bàn đang dùng → đặt món hộ; counter chuyển món confirmed → preparing → ready.
4. Waiter vào Tác vụ → Món chờ bưng → Đã phục vụ. Bước này chưa ghi doanh thu.
5. Counter thanh toán; đối chiếu hóa đơn, phiên paid, bàn chờ dọn. Waiter đánh dấu đã dọn xong để trả bàn trống.
6. Thử yêu cầu từ bàn và đơn khách pending nếu đã có customer/dữ liệu phù hợp.

Khu Demo tích hợp có giờ tạo cố định, có thể đã quá hạn. Không reset dữ liệu chung; tạo phiên/đặt bàn mới khi thử. Xem `../../docs/TEAM_DEMO_DATA.md`.

## Giao diện và giới hạn

- Lưới bàn tự tăng số cột theo chiều rộng; đã thêm cảnh báo sắp hết/quá giờ trên màn hình, không phụ thuộc quyền thông báo/rung của laptop. Giữ tab hoạt động khi demo, trình duyệt có thể giảm tần suất timer ở nền.
- Bản web không khởi tạo plugin thông báo native. Cảnh báo OS/rung không phải điều kiện bắt buộc của demo laptop.
- Cấu hình web hiện dùng Firebase web app cùng project với counter. Phát hành riêng có thể đăng ký web app waiter riêng trong cùng project và sinh lại FlutterFire config.
- Android và Windows native chưa nghiệm thu; ưu tiên `-d chrome`, không dùng cấu hình này để khẳng định APK đã build thành công.
- Test dùng dữ liệu giả, không ghi lên Firestore chung. Chưa thay thế buổi nghiệm thu thực tế trên nhiều máy.

## Kiểm tra

```powershell
flutter analyze
flutter test --concurrency=1
flutter build web --release --no-wasm-dry-run
```

Đã kiểm tra lại ngày 29/10/2026: analyze không có góp ý, 9 test pass và build web release thành công. Đã thử UI thật với customer/counter: duyệt đơn, giao món, xử lý requests, dọn bàn và chuyển bàn. Xem `../../docs/DEMO_RUNBOOK.md` để biết dữ liệu và các giới hạn còn lại.
