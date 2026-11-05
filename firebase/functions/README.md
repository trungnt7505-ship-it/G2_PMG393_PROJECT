# Backend gửi FCM khi demo

Từ PowerShell trong `D:\Project_PRM`, chạy một lần cho buổi demo.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-push-backend.ps1
```

Giữ terminal và kết nối Internet. Dừng bằng Ctrl+C. Chương trình sử dụng tài khoản đã đăng nhập bằng Firebase CLI trên máy. Nếu chưa đăng nhập, chạy `firebase login`. Tài khoản cần quyền đọc/ghi Firestore và gửi FCM của dự án cafe-73637. Chỉ chạy backend trên máy của người quản lý dự án. Credential tạm nằm trong thư mục Temp của Windows và được xóa khi chương trình thoát bình thường. Không đưa credential vào Git hoặc ứng dụng Android.

Kiểm tra kết nối mà không gửi thông báo.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-push-backend.ps1 -Check
```

Chương trình theo dõi yêu cầu release_table đang mở được tạo trong 15 phút gần nhất. Kiểm tra tài khoản người tạo thuộc nhân viên và khách của phiên bàn, gửi FCM đến các thiết bị Customer đã đăng ký. Phiên khách vãng lai không gửi push. Chưa có token hoặc lỗi tạm thời thì thử lại. Các yêu cầu đã xử lý được ghi ở `_notificationDeliveries` để tránh gửi lại khi khởi động lại worker. Hai worker dùng lease để tránh cùng xử lý. Nếu chương trình bị ngắt đúng sau khi gửi nhưng trước khi ghi kết quả thì có thể gửi lại, Android dùng cùng tag để thay thông báo cũ.

Customer phải được cài lại sau khi thêm firebase_messaging, đăng nhập tài khoản và cho phép thông báo. Khóa màn hình, để Waiter gửi yêu cầu mới, sau đó chạm thông báo và mở khóa để đến phiên bàn. Firebase Cloud Messaging cần Google Play services. Âm thanh phụ thuộc âm lượng thông báo và chế độ Không làm phiền.

Backend này chạy trên laptop, không cần triển khai Cloud Functions. Khi terminal/laptop dừng, push mới sẽ chờ chương trình chạy lại trong thời hạn 15 phút. Thông báo chờ trên FCM cũng có thời hạn 15 phút để tránh nhắc cũ quá lâu.
