# Kết quả kiểm tra demo — 29/10/2026

## Kết luận và phạm vi

Có thể demo luồng **check-in tại quầy → khách gọi món → waiter duyệt/giao món → counter thanh toán → khách xem điểm/hóa đơn → waiter dọn bàn** trên ba bản web kết nối Firestore thật, project `cafe-73637`.

Đã chạy ba phiên trình duyệt trên cùng laptop, tách origin bằng ba cổng. Chưa phải nghiệm thu trên ba laptop vật lý hoặc xác nhận tất cả chức năng sản phẩm hoàn thành.

## Mở ứng dụng

| App | URL khi server đang chạy | Vai trò |
| --- | --- | --- |
| Counter | http://localhost:5201 | counter/manager |
| Waiter | http://localhost:5202 | waiter/manager/counter |
| Customer | http://localhost:5203 | customer |

Nếu khởi động lại máy, chạy từng lệnh ở terminal riêng trong thư mục app tương ứng:

```powershell
flutter run -d chrome --web-port 5201
flutter run -d chrome --web-port 5202
flutter run -d chrome --web-port 5203
```

Chạy counter trong `apps/counter_app`, waiter trong `apps/waiter_app`, customer trong `apps/customer_app`. Sau khi cập nhật core, resolve lại dependencies của mỗi app. Nếu `flutter pub get` bị chặn symlink Windows native, cần cấu hình Developer Mode theo hướng dẫn Flutter; không xem đó là lỗi Firebase. Trong lượt kiểm tra này đã resolve dependency và chạy web/test với `--no-pub`.

Tài khoản thử:

- Customer: `demo.flow.20261029.customer@example.com`.
- Counter: `demo.flow.20261029.counter@example.com`.
- Waiter: `waiter.laptop.20261026@example.com`.

Mật khẩu được cung cấp riêng trong chat; không lưu trong repository. Không tự tạo role hoặc dùng tài khoản đăng nhập giả khi Firebase lỗi.

## Dữ liệu và kịch bản đã thử

Khu `Demo 29/10`, bàn `demo_flow_20261029` và `demo_flow_20261029_preorder`; món `demo_flow_coffee_20261029`, giá 20.000đ. Các thử nghiệm ghi dữ liệu thật nên có ảnh hưởng tới thống kê hôm nay. Không xóa dữ liệu cũ của nhóm.

| Luồng | Kết quả thực tế |
| --- | --- |
| Đăng nhập ba app | Đọc được đúng hồ sơ và dữ liệu Firebase |
| Customer tìm bàn, đặt bàn kèm món | Thành công, hiển thị QR `cafe://preorder/r7lqSG43JXelWv88e0zk` |
| Customer hủy lịch trên | Chuyển cancelled; kiểm tra Firestore xác nhận 5 slot đã được giải phóng |
| QR bàn sai secret | Bị từ chối, không mở phiên |
| QR đặt trước tại counter | Mở phiên, tạo món confirmed, customer tự thấy banner phiên bàn, waiter thấy bàn đang dùng |
| Customer gọi thêm món | Đơn pending, chưa cộng vào subtotal |
| Waiter duyệt | Đơn confirmed, tổng tạm tính tăng từ 20.000 lên 40.000đ |
| Counter pha chế → waiter mang ra | Hai đơn served; kiểm tra paymentCount vẫn là 0 trước khi chốt tiền |
| Thanh toán khi còn pending | Backend từ chối, chưa ghi payment; thêm chặn ngay nút mở thanh toán để tránh thông báo lỗi khó hiểu trên web |
| Gọi phục vụ/yêu cầu tính tiền | Waiter nhận được request realtime và xử lý được |
| Trả sớm | Phiên billing; dự tính thêm 20 điểm khi thanh toán |
| Thanh toán tại bàn | 40.000đ; nhận 4 điểm tích lũy +10 preorder +20 trả sớm =34 điểm |
| Dọn bàn | Waiter thấy needs_cleaning, đánh dấu dọn xong → available |
| Mang đi, giao trước thu tiền | served vẫn hiện “Chưa thu tiền”, chưa biến mất khỏi queue |
| Đổi điểm mang đi | Nhập 999 bị giới hạn 10 điểm trên bill 20.000đ; thực thu 10.000đ; cộng 1 điểm |
| Điểm cuối cùng | 34−10+1 =25 điểm, xác nhận trên customer và Firestore |
| Lịch sử hóa đơn | Hai hóa đơn tải được, xem lại snapshot danh sách món, không thực hiện thanh toán lại |
| Gia hạn phiên có reservation | Sau sửa, customer báo thêm 30 phút, đồng hồ tăng từ gần 2 giờ lên gần 2 giờ 30 |
| Chuyển bàn | Waiter chuyển giữa hai bàn demo, tên bàn trong customer đổi theo; bàn cũ chờ dọn |
| Hủy phiên mở thử chưa có món | Session cancelled; sau khi phát hiện slot còn giữ, đã sửa service và thêm test cleanup/ownership |

Lịch nhận bàn tại quầy dùng fixture `demo_flow_preorder_20261029` có thời gian gần hiện tại để không phải chờ giới hạn đặt trước tối thiểu. Việc tạo/hủy lịch hợp lệ qua UI đã được kiểm tra riêng. Fixture gia hạn là `demo_flow_extend_20261029`; phiên thử đã hủy và các slot còn lại đã được dọn đúng batch. Fixture không tự cập nhật thời gian cho ngày demo tiếp theo.

Đối soát thanh toán:

- Payment tại bàn: `RkZ35XUH6c8BSFOdfE3u`, session `FCaw4YjkTbVbIoKQrjfK`, thực thu 40.000đ.
- Payment mang đi: `takeaway_BSLiLzDdOGYQtr1RJlTl`, thực thu 10.000đ.
- Tổng thực thu của hai bill thử: **50.000đ**. Đây là số tăng do bài kiểm tra, không nhất thiết là tổng doanh thu toàn quán.

## Các sửa chữa trong lượt kiểm tra

- Bỏ fallback đặt bàn bằng WriteBatch sau lỗi transaction; đặt bàn chỉ ghi qua transaction kiểm tra slot.
- Gia hạn bỏ qua slot của chính reservation đã check-in, vẫn giới hạn theo reservation khác.
- Counter không đăng nhập giả khi Firebase lỗi; bỏ các nút điền tài khoản/mật khẩu mẫu không được xác nhận.
- Chặn mở thanh toán nếu chưa tải xong đơn hoặc còn pending; backend tiếp tục kiểm tra lần cuối.
- Phiên paid/cancelled trên customer hiển thị đúng trạng thái và ngừng hiển thị đồng hồ đang hoạt động.
- Thêm index payments(customerId ASC, paidAt DESC) trong `firebase/firestore.indexes.json`, tạo trên Firebase thật; lịch sử hóa đơn đã được kiểm tra lại thành công sau khi index sẵn sàng.
- Hủy mở nhầm chỉ cho phiên đang mở, không có subtotal/đơn chưa hủy, bàn vẫn trỏ đúng phiên; cập nhật lịch liên kết và giải phóng đúng slot, kể cả sau chuyển bàn. Test chặn hủy phiên paid/pending hoặc bàn đã thuộc phiên khác.

## Giới hạn cần tránh khi demo

- **Customer tự check-in QR tại bàn vẫn bị Rules chặn cập nhật tables.** Không thay đổi Rules để mở rộng quyền trong lượt kiểm tra. Khi demo, khách đưa QR lịch đặt cho counter nhận bàn. UI giải thích cách xử lý khi gặp permission-denied.
- Chỉ check-in trong cửa sổ hợp lệ (theo checkInEarlyMinutes/holdUntil). Đặt lịch quá xa rồi quét ngay bị từ chối là đúng nghiệp vụ.
- QR nhập tay đã thử; chưa xác nhận camera thật, Google sign-in, gửi email reset, notification/rung native hoặc APK release.
- Chưa stress-test hai khách đặt đồng thời/mạng mất giữa commit trên backend thật. Test transaction lỗi/slot đã bị giữ và chống thanh toán lặp đã có trong bộ test.
- Màn hình admin thống kê/cấu hình có test, nhưng lượt thử UI thật này dùng tài khoản counter, chưa nghiệm thu lại admin UI thật.
- Dữ liệu seed cũ vẫn còn trong queue/cảnh báo; khi trình bày chỉ thao tác đúng các bàn và món của khu Demo 29/10.

## Kiểm thử tự động

Core: 39 test; customer: 10; counter: 26; waiter: 9 — tổng **84 test pass** trong lượt kiểm tra. Analyze core và ba app đạt; các bản web release đã build và mở được. Bộ test là kiểm tra bổ sung, không thay thế các giới hạn thực tế ở trên.

## Cập nhật luồng yêu cầu — 02/11/2026

- Customer: camera QR thật (mobile_scanner), có nhập mã dự phòng. Chỉ nhận đặt bàn của chính mình đang trong cửa sổ check-in; khách vãng lai nhờ Waiter mở bàn.
- Firestore Rules kiểm tra bàn trống, khách sở hữu đặt bàn, đúng QR, giờ nhận, và cập nhật đồng thời reservation/session/table. Rules đã triển khai lên cafe-73637; script `scripts/test-checkin-rules.cjs` kiểm tra 5 trường hợp trên emulator cổng 8188, project demo-cafe.
- Món đặt trước của khách tự check-in được tạo ở trạng thái pending để nhân viên duyệt. Nhân viên check-in hộ vẫn theo luồng confirmed hiện có.
- Customer nhìn thấy yêu cầu nhả bàn của Waiter trong màn hình phiên; có thể yêu cầu tính tiền/gọi phục vụ. Khi hết giờ có cảnh báo trên màn hình, không tự đuổi khách hoặc tự thu tiền.
- Cảnh báo phiên được kiểm tra mỗi giây khi màn hình phiên mở. Android xin quyền notification; rung phụ thuộc thiết bị và quyền. Chưa cam kết thông báo khi ứng dụng bị đóng/hệ điều hành dừng ứng dụng.
- Menu trang chủ thêm món vào giỏ của phiên đang hoạt động; khách kiểm tra giỏ và gửi đơn để nhân viên duyệt.
- Chống đặt trùng dùng kiểm tra khoảng thời gian và guard phiên bản theo bàn/tài khoản. Các máy phải cùng dùng bản core mới. Dữ liệu trùng cũ không tự hủy. Slot cũ không có bookingStart/bookingEnd được kiểm tra bảo thủ theo từng khoảng 30 phút.
- Đặt mang đi online và gia hạn qua Waiter duyệt chưa triển khai theo yêu cầu hoãn của người dùng.
- Phần cứng camera/rung và ba máy vật lý vẫn cần nghiệm thu thực tế. Build web/test phần mềm không thay thế kiểm thử này.

## Bốn luồng bổ sung — 02/11/2026

1. **Gia hạn có duyệt:** Customer gửi yêu cầu `extend_session`; thời gian không đổi khi gửi. Waiter vào Tác vụ → Yêu cầu để duyệt hoặc từ chối. Duyệt kiểm tra lại phiên và lịch đặt kế tiếp, cập nhật thời gian và kết quả yêu cầu trong cùng transaction. Một yêu cầu chỉ được xử lý một lần. Customer xem kết quả trong phiên bàn. Thông báo hiện realtime trong app đang mở, chưa phải push khi đóng app.
2. **Món đặt trước:** Waiter có tab Món đặt trước, thấy khách, điện thoại, bàn, giờ đến, món/tùy chọn/ghi chú và tổng tiền, xác nhận đã tiếp nhận. Không tạo thêm đơn bếp ở bước tiếp nhận; check-in vẫn tạo đúng đơn theo luồng hiện có.
3. **Mang đi online:** Customer mở Đặt món mang đi / Theo dõi đơn từ trang chủ. Tên/SĐT lấy từ hồ sơ, có thể sửa cho riêng đơn; chọn nhận sớm nhất hoặc hẹn giờ trong ngày; chọn món và gửi. Nhân viên duyệt và chuẩn bị qua hàng đợi hiện có. Khách theo dõi trạng thái và thanh toán tại quầy. Không có thanh toán ngân hàng online/giao hàng. Đơn lưu snapshot người nhận và mã chống gửi lặp, hóa đơn gắn tài khoản đặt.
4. **Chờ thanh toán:** Counter hiển thị cả phiên billing hoặc có yêu cầu request_bill đang mở, cùng đơn mang đi ready/served chưa thu tiền. Thu tiền bàn kiểm tra món pending trước và dùng lại giao dịch checkout hiện có.

Kiểm thử mới: yêu cầu gia hạn không tăng giờ trước khi duyệt; không duyệt hai lần; từ chối giữ nguyên giờ; đơn online giữ snapshot/giá menu và không nhân đôi khi gửi lại; tiếp nhận đặt trước không tạo đơn bếp; giao diện Counter có bàn xin hóa đơn. Rules emulator chặn khách tự tăng giờ và tự duyệt yêu cầu.

## Cảnh báo giờ trên giả lập Android — 05/11/2026

- Khi đang mở màn hình Phiên bàn của Customer: hiển thị cảnh báo nổi 10 giây và banner tại các mốc warnMinutes (mặc định 15/5 phút) và khi hết giờ; mỗi mốc chỉ báo một lần cho mỗi hạn phiên.
- Android dùng kênh thông báo có âm thanh `table_session_sound_v2`. Cấp quyền thông báo, bật âm lượng thông báo của giả lập và loa máy tính, tắt chế độ Không làm phiền để nghe tiếng báo hệ thống. Nếu từ chối quyền, thông báo trong app vẫn hiển thị nhưng âm thanh hệ thống không được bảo đảm.
- Sau khi gia hạn được duyệt, các mốc cảnh báo được thiết lập lại. Không báo hết giờ khi vẫn còn dưới một phút.
- Chưa có lập lịch báo động khi đóng app; âm thanh này dành cho Android, chưa bổ sung âm thanh trình duyệt. Customer vẫn cần cấu hình Firebase Android trước khi chạy trên giả lập.

## Firebase Android — 05/11/2026

Cả ba app dùng dự án cafe-73637, chung Authentication và Firestore (default):

| App | Android package | Firebase App ID |
| --- | --- | --- |
| Counter | com.cafe.counter_app | 1:881262711524:android:c651fe03c0af3ba09f52f1 |
| Customer | com.cafe.customer_app | 1:881262711524:android:c522b63f25ecde019f52f1 |
| Waiter | com.cafe.waiter_app | 1:881262711524:android:5d3bf58f8ec18f589f52f1 |

Mỗi app có android/app/google-services.json và FirebaseOptions.android tương ứng; firebase.json ghi lại mapping. Không sao chép cấu hình Android của Counter sang app khác. Web tiếp tục dùng cấu hình hiện có. Không thay đổi Rules hay dữ liệu khi đăng ký thêm app Android. Đây là cấu hình kết nối; vẫn cần kiểm thử đăng nhập email/mật khẩu, camera và thông báo trên thiết bị. Google Sign-In nếu sử dụng cần đăng ký SHA chứng chỉ ký của máy/build tương ứng.

Kiểm tra cấu hình: package Android, App ID trong google-services.json và FirebaseOptions đã đối chiếu khớp cho cả ba app; flutter analyze không có lỗi. Build debug Customer/Waiter ngày 05/11 bị gián đoạn do tranh chấp khóa cache Gradle với các tiến trình khác; chưa có kết quả APK thành công, chưa kiểm thử thiết bị.
