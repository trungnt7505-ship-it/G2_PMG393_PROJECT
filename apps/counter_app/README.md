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

Giữ các collection và hàm cũ. Bổ sung trường tùy chọn `orders.paymentId`, `sessions.orderRevision`, và danh sách món đã chốt trong hóa đơn. Không cần sửa rules/indexes hoặc di chuyển dữ liệu cũ. Hai ứng dụng còn lại không bị sửa mã nguồn; cần cập nhật `core` để dùng các quy tắc cấu hình mới. Các lời gọi hiển thị/cảnh báo cũ vẫn dùng ngưỡng mặc định nếu không truyền cấu hình.

```powershell
flutter analyze
flutter test
flutter build web --release
```

Chạy thêm `flutter test` tại `packages/core` để kiểm tra transaction thanh toán, chống thanh toán lặp, cấu hình và thống kê. Kiểm thử Firestore dùng dữ liệu giả trong bộ nhớ, không ghi dữ liệu thử lên database chung.

