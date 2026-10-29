# Counter App (POS & Quản lý)
Phụ trách: TRƯỜNG

## Chạy trên laptop

```powershell
flutter pub get
flutter run -d chrome
```

## Thanh toán và quản trị

- Tại bàn: mở chi tiết bàn → **Thanh toán & Đóng bàn**. Duyệt hoặc từ chối hết đơn chờ trước khi thanh toán. Đơn hủy không nằm trong hóa đơn. Chọn thành viên qua QR/SĐT để tích hoặc đổi điểm.
- Mang đi: tạo đơn → pha chế → sẵn sàng → **Thu tiền**. Bấm **Đã phục vụ** không tự ghi doanh thu; đơn chưa thu tiền vẫn ở bộ lọc **Chờ thanh toán**. Đơn thu tiền trước vẫn chờ giao; chỉ rời hàng đợi khi vừa thanh toán vừa đã phục vụ.
- QR/thẻ là phương thức ghi nhận thu tiền do thu ngân xác nhận, chưa kết nối cổng thanh toán tự động. Hóa đơn xem trên màn hình, không yêu cầu máy in.
- Quản lý → **Cấu hình App**: sửa, lưu hoặc bỏ bản nháp. Lưu thất bại giữ dữ liệu nhập. Nếu máy khác vừa đổi cấu hình, tải lại trước khi lưu.
- Cấu hình thời lượng áp dụng cho các thao tác mở/gia hạn phiên mới; không sửa thời điểm kết thúc đã lưu của phiên đang chạy. Thanh toán dùng cấu hình tại lúc chốt. Tổng thời lượng phiên và dọn bàn tối đa 150 phút để phù hợp 5 khung giữ chỗ hiện tại.
- **Thống kê & Dữ liệu mẫu**: doanh thu và số hóa đơn lấy từ thanh toán trong ngày; số phiên lấy các phiên bắt đầu trong ngày, không tính phiên hủy hoặc đơn mang đi. Chọn **Thử lại** nếu tải thống kê lỗi.

## Tương thích và kiểm thử

Giữ các collection và hàm cũ. Bổ sung trường tùy chọn `orders.paymentId`, `sessions.orderRevision`, và danh sách món đã chốt trong hóa đơn. Không cần di chuyển dữ liệu cũ. Lịch sử hóa đơn customer cần index payments(customerId ASC, paidAt DESC), đã bổ sung và tạo trên Firebase trong lượt kiểm tra 29/10. Cập nhật core và dependency cho cả ba app; các lời gọi hiển thị/cảnh báo cũ vẫn dùng ngưỡng mặc định nếu không truyền cấu hình.

```powershell
flutter analyze
flutter test
flutter build web --release
```

Chạy thêm `flutter test` tại `packages/core` để kiểm tra transaction thanh toán, chống thanh toán lặp, cấu hình và thống kê. Kiểm thử Firestore dùng dữ liệu giả trong bộ nhớ, không ghi dữ liệu thử lên database chung.

## Hóa đơn và giao diện laptop (phần 7–8)

- Hóa đơn dài có thể cuộn, xem size/topping/ghi chú và chọn để sao chép mã hóa đơn. Không có thao tác gửi tới máy in.
- Quản lý → Thống kê → chọn một hóa đơn trong danh sách hôm nay để xem lại. Nút **Thử lại** chỉ tải chi tiết, không thu tiền lần nữa.
- Màn hình rộng từ 1200 px giữ ba cột; cửa sổ nhỏ hơn dùng ba tab Sơ đồ bàn / Pha chế / Chi tiết bàn. Chọn bàn sẽ chuyển sang tab chi tiết.
- Bộ lọc khu vực đọc từ Firestore, gồm cả khu Demo tích hợp. Database trống hiển thị trạng thái trống, không tạo bàn giả trên giao diện.
- Khi đang duyệt/hủy/chuyển trạng thái/xử lý yêu cầu, POS chặn thao tác lặp và hiển thị thanh tiến trình. Lỗi được báo bằng thông báo trên màn hình.
- Nếu không mở được camera, có thể nhập nội dung QR thủ công.

## Kiểm chứng phần 9

```powershell
flutter test --concurrency=1
flutter build web --release --no-wasm-dry-run
flutter build apk --release
```

- `pos_ux_test.dart`: bố cục 1366×768, 1024×600, 800×600; hóa đơn dài; thử lại tải biên lai; chống bấm lặp; database trống.
- `cross_role_flow_test.dart`: dùng service thật trên Firestore giả lập, kiểm tra khách đặt món trước → quầy nhận QR → phục vụ duyệt/pha chế/giao món → yêu cầu tính tiền → thanh toán → điểm/thống kê/dọn bàn. Đây là kiểm thử hợp đồng service, không phải kiểm thử giao diện của ba ứng dụng thật hoặc Security Rules trên Firebase.
- Waiter đã có code và nền tảng web để chạy laptop; xem `../waiter_app/README.md` (cổng waiter 5202, counter 5201). Customer đã tích hợp từ main; xem `../customer_app/README.md`, có thể chạy cổng 5203. Cần thử nghiệm đồng bộ nhiều máy thực tế; chưa coi test service là nghiệm thu cả ba app.
- Android đã bổ sung Gradle wrapper, Activity và resource còn thiếu. Gradle giới hạn 1536 MB heap và 2 worker để giảm tải. Lần build APK trước bị ngắt do máy crash; APK chưa được xác nhận tạo thành công. Chạy lại riêng lệnh build APK khi máy ổn định, tránh chạy cùng lúc nhiều build/test.

