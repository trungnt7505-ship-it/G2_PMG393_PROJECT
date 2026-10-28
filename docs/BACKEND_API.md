# Backend, database và API của hệ thống Cafe

Ngày đối chiếu: 19/10/2026. Tài liệu này tổng hợp cấu hình và mã nguồn trong workspace; đây không phải kết quả đăng nhập Firebase Console hay kiểm tra dữ liệu production.

## Kết luận nhanh

- **Backend được thiết kế và một phần đã nối:** Firebase Authentication + Cloud Firestore. `.firebaserc` chọn project `cafe-73637`; `firebase.json` trỏ tới rules và indexes trong `firebase/`; cấu hình Firebase Android/Web trong `apps/counter_app` cũng trỏ project này. `counter_app/lib/main.dart` khởi tạo Firebase.
- **Customer app đã có kết nối khởi đầu trong source:** `apps/customer_app` có pubspec trỏ tới core, Firebase options/bootstrap, đăng nhập/đăng ký bằng AuthService và đọc profile/menu qua core providers. Các luồng đặt bàn, QR, phiên, gửi món và lịch sử vẫn chưa làm xong. Chưa chạy xác nhận build/runtime; Android cũng cần đăng ký app khách riêng và runner platform cho bản phát hành.
- **Database:** Cloud Firestore database `(default)` của project `cafe-73637` đã có dữ liệu customer theo thông tin Console do người dùng cung cấp. Link Console trỏ đến project này và đường dẫn document `users/demo_team_customer_chi`; vì vậy có thể xác nhận database tồn tại và đã có ít nhất dữ liệu khách hàng theo xác nhận đó. Repo không tạo database. Link không cung cấp nội dung document/rules, nên không xác nhận các giá trị cụ thể bên trong, rules/indexes đã deploy hay tất cả collection đã được seed.
- `SeedService.seedInitialDataIfEmpty()` có thể tạo `config/app`, 12 bàn mẫu và 10 món mẫu khi chạy trên Firestore thật và các collection tương ứng rỗng. Việc có hàm seed không chứng minh seed đã chạy. Seed không tạo tài khoản Firebase Auth.
- Không thấy REST API/server riêng trong repo. Các API nghiệp vụ là Dart service gọi Firebase SDK trực tiếp từ `packages/core`; Firestore Streams cung cấp cập nhật realtime và transaction/batch xử lý ghi có tính nhất quán.
- `cash`, `qr`, `card` là lựa chọn phương thức được ghi nhận; chưa thấy cổng thanh toán hoặc xác minh giao dịch ngân hàng tự động.

## Luồng kết nối

```text
Flutter app (đã bootstrap: counter_app)
  -> Firebase.initializeApp(FirebaseOptions)
  -> Firebase Authentication (đăng nhập / UID)
  -> packages/core services và providers
  -> Cloud Firestore project cafe-73637, database (default)
       -> users, tables/slots, menuItems, reservations,
          sessions/orders, requests, payments, config
```

Customer app hiện bootstrap với options Web hiện có và Android app ID trích từ cấu hình counter_app; trước khi phát hành Android cần đăng ký customer app ID riêng và tạo options tương ứng từ Firebase Console/FlutterFire. Không dùng cấu hình Windows trong counter_app vì đang trỏ project demo `cafe-system-prm393`. `firebase/firestore.rules` là cấu hình quyền được version-control; sự hiện diện của file không chứng minh rules đó đã deploy.

## Dữ liệu Firestore

| Collection/path | Nội dung |
| --- | --- |
| `users/{uid}` | Hồ sơ, role, điểm, thông tin liên hệ. UID cần khớp Firebase Auth. |
| `users/{uid}/pointTx/{txId}` | Nhật ký cộng/trừ/bonus điểm, có thể kèm paymentId. |
| `tables/{tableId}` | Bàn, sức chứa, khu vực, trạng thái vật lý và phiên hiện tại. |
| `tables/{tableId}/slots/{yyyyMMddHHmm}` | Slot giữ chỗ để ngăn hai reservation trùng giờ. |
| `menuItems/{itemId}` | Món, giá, availability và tùy chọn/giá thêm. |
| `reservations/{resId}` | Lịch đặt, khách, bàn, thời gian, trạng thái và món preorder. |
| `sessions/{sessionId}` | Phiên bàn, thời hạn, tổng tạm tính và trạng thái. |
| `sessions/{sessionId}/orders/{orderId}` | Đơn món của phiên. Đơn mang đi ở `sessions/takeaway_orders/orders/{orderId}`. |
| `requests/{reqId}` | Gọi phục vụ, yêu cầu tính tiền/nhả bàn/trả sớm. |
| `payments/{payId}` | Hóa đơn, tổng tiền, điểm và thời điểm thanh toán; thường có snapshot `items`. |
| `config/app` | Cấu hình thời lượng, giữ chỗ, cảnh báo và quy đổi điểm. |

Firestore Timestamp dùng cho các trường thời gian. Schema chi tiết và trạng thái chuẩn nằm ở Mục 3–4 `PROJECT_SPEC.md`.

## API service và mục đích

Các chữ ký dưới đây rút gọn theo source thực tế trong `packages/core/lib/services/`. Tất cả API Firestore chạy từ core, không từ widget. `Future` thường là thao tác đọc/ghi một lần; `Stream` theo dõi thay đổi realtime.

### AuthService — `auth_service.dart`

| API | Mục đích |
| --- | --- |
| `currentUid` | UID Firebase Auth đang đăng nhập, hoặc null. |
| `watchCurrentUser()` | Theo dõi Auth state và hồ sơ `users/{uid}` realtime. |
| `signInWithEmail(email, password, {required allowedRoles})` | Đăng nhập Firebase Auth, đọc hồ sơ Firestore, chặn role không thuộc app và đồng bộ giờ server. |
| `registerCustomer({email, password, displayName, phone})` | Tạo tài khoản Auth và hồ sơ khách `role=customer`; đồng bộ giờ. |
| `signOut()` | Đăng xuất Firebase Auth. |
| `findCustomerById(uid)` | Tra UID và chỉ trả hồ sơ nếu role là customer. |
| `findCustomerByPhone(phone)` | Tra hồ sơ theo số điện thoại; source hiện chưa lọc role customer ở hàm này. |

### ClockService — `clock_service.dart`

| API | Mục đích |
| --- | --- |
| `ClockService.instance` | Singleton đồng hồ dùng chung. |
| `syncClock(uid)` | Ước lượng lệch đồng hồ client với server bằng `serverTimestamp`; lỗi mạng giữ offset cũ. |
| `serverNow` | Thời gian client đã cộng offset; dùng khi tính hạn phiên/slot theo hợp đồng. |
| `setOffsetForTesting(duration)` | Đặt offset cho unit test. |

### ReservationService — `reservation_service.dart`

| API | Mục đích |
| --- | --- |
| `getAvailableTables({startTime, partySize})` | Lọc theo sức chứa và kiểm tra 5 slot, trả các bàn chưa xung đột. |
| `createReservation(draft)` | Transaction kiểm tra config/thời gian/slot, khóa slot và lưu reservation. |
| `cancelReservation(reservationId)` | Transaction chuyển cancelled và giải phóng slot của reservation. |
| `sweepNoShows()` | Tìm reservation confirmed quá `holdUntil`, chuyển no_show và xóa slot; cần được gọi chủ động, chưa có scheduler backend. |
| `watchCustomerReservations(customerId)` | Stream lịch đặt của khách, mới nhất trước. |
| `watchTodayConfirmedReservations()` | Stream lịch confirmed có giờ bắt đầu trong ngày. |
| `watchTodayNoShows()` | Stream lịch no_show có giờ bắt đầu trong ngày. |

### SessionService — `session_service.dart`

| API | Mục đích |
| --- | --- |
| `computeDisplayStatus(table, activeSession, nextRes, now, {config})` | Tính trạng thái màu/UI bàn: free, reservedSoon, using, expiring, overtime, cleaning. |
| `openSession({tableId, customerId, customerName, openedBy, openedByRole, reservationId})` | Transaction mở phiên, chiếm bàn, xử lý check-in reservation/preorder và ràng buộc slot. |
| `checkInByTableQr({qrContent, customerId, reservationId})` | Xác thực QR bàn và mở/check-in phiên khách. |
| `checkInByPreOrderQrAtCounter({qrContent, counterUid, assignTableId})` | Quầy xác nhận QR preorder, mở phiên/đơn và có thể gán bàn. |
| `extendSession(sessionId, {byUid})` | Gia hạn theo config, giới hạn bởi lịch reservation kế tiếp. |
| `requestEarlyRelease(sessionId, {customerId})` | Kiểm tra điều kiện trả sớm, đánh dấu phiên billing/earlyReleased và tạo request. |
| `switchTable({sessionId, newTableId, oldTableNeedsCleaning})` | Chuyển phiên sang bàn khác. |
| `cancelMistakenSession(sessionId)` | Hủy phiên mở nhầm. |
| `markTableCleaned(tableId)` | Đánh dấu bàn đã dọn, đưa bàn về available. |
| `sendTableRequest({sessionId, tableId, tableName, type, createdBy, message})` | Tạo request phục vụ/tính tiền/nhả bàn. |
| `resolveRequest(requestId)` | Đánh dấu request đã xử lý. |
| `watchSession(sessionId)` | Stream một phiên. |
| `watchActiveSessions()` | Stream các phiên active/billing. |
| `watchAllTables()` | Stream danh sách bàn. |
| `watchOpenRequests()` | Stream request đang mở. |
| `watchTodaySessions()` | Stream phiên bắt đầu trong ngày, loại document `takeaway_orders`. |

### OrderService — `order_service.dart`

| API | Mục đích |
| --- | --- |
| `submitOrder({sessionId, tableId, tableName, items, createdBy, createdByRole, type})` | Kiểm tra menu/giá hiện hành rồi lưu order; customer tạo pending, staff tạo confirmed và tính vào subtotal. |
| `approveOrder(sessionId, orderId)` | Duyệt pending và cộng tiền vào subtotal. |
| `cancelOrder(sessionId, orderId, {reason})` | Hủy order, điều chỉnh subtotal nếu đơn đã tính; chặn trường hợp phiên đóng/đơn takeaway đã thanh toán theo nghiệp vụ. |
| `updatePreparationStatus(sessionId, orderId, newStatus)` | Cập nhật tiến độ pha chế/phục vụ. |
| `watchSessionOrders(sessionId)` | Stream đơn của phiên. |
| `watchAllOrdersByStatuses(statuses)` | Stream collectionGroup orders theo trạng thái, dùng cho hàng đợi quầy. |
| `toggleMenuItemAvailability(itemId, isAvailable)` | Bật/tắt món trên menu (API quản trị). |

### PaymentService — `payment_service.dart`

| API | Mục đích |
| --- | --- |
| `calculatePayment({subtotal, pointsUsed, earlyReleased, hasPreOrder, config})` | Hàm thuần tính giảm giá/điểm; hỗ trợ preview UI và test. |
| `payAndClose({sessionId, cashierId, method, customerId, pointsUsed, expectedSubtotal, expectedConfig})` | Transaction chốt phiên, chặn order pending/thanh toán lặp, ghi payment + snapshot, cập nhật điểm/session/bàn và giải phóng slot liên quan. |
| `payTakeaway({orderId, cashierId, method, customerId, pointsUsed, expectedSubtotal, expectedConfig})` | Thanh toán một đơn mang đi ready/served, chống thu tiền trùng, không đóng bàn. |
| `getPaymentItems(paymentId)` | Đọc snapshot món để xem lại hóa đơn. |
| `watchSessionPayment(sessionId)` | Stream payment của phiên. |
| `watchTodayPayments()` | Stream hóa đơn có paidAt trong ngày. |

`expectedSubtotal` và `expectedConfig` giúp phát hiện màn hình checkout đã cũ. `method` hiện chỉ ghi loại cash/qr/card, không tự giao dịch với ngân hàng.

### ConfigService, AlarmService, SeedService

| Service/API | Mục đích |
| --- | --- |
| `ConfigService.read({transaction})` | Đọc `config/app`, dùng default khi thiếu và validate. Có thể đọc trong transaction. |
| `ConfigService.save(config, {expected})` | Validate, merge giữ trường mở rộng và tùy chọn phát hiện cấu hình đã bị máy khác thay đổi. |
| `AlarmService.init()` | Khởi tạo local notifications. |
| `syncAlarmsForSession(session, {config})` | Phát rung/thông báo tại ngưỡng cảnh báo và 0 cho phiên; chống lặp theo session trên thiết bị. |
| `onTickCheck(activeSessions, {config})` | Kiểm tra cảnh báo cho danh sách phiên đang theo dõi. |
| `resetSessionAlarms(sessionId)` | Xóa dấu mốc đã phát của phiên. |
| `SeedService.seedInitialDataIfEmpty()` | Tạo config, bàn mẫu, menu mẫu nếu thiếu; không seed Auth và không ghi đè collection đã có dữ liệu. |

## Riverpod providers dùng chung

Khai báo trong `packages/core/lib/providers/core_providers.dart`; UI nên đọc provider thay vì tự subscribe Firestore.

| Provider | Dữ liệu / tác dụng |
| --- | --- |
| `clockServiceProvider`, `authServiceProvider`, `reservationServiceProvider`, `sessionServiceProvider`, `orderServiceProvider`, `paymentServiceProvider`, `alarmServiceProvider`, `seedServiceProvider`, `configServiceProvider` | Cung cấp singleton/service cho ViewModel. |
| `currentUserProvider` | Hồ sơ người dùng đang đăng nhập. |
| `appConfigProvider` | Stream `config/app`, default nếu document thiếu. |
| `allTablesProvider`, `activeSessionsProvider`, `openRequestsProvider` | Bàn, phiên active/billing và request mở. |
| `todayConfirmedReservationsProvider`, `todayNoShowsProvider`, `todaySessionsProvider`, `todayPaymentsProvider` | Dữ liệu nghiệp vụ trong ngày. |
| `customerReservationsProvider(customerId)` | Lịch đặt riêng theo khách. |
| `sessionStreamProvider(sessionId)`, `sessionOrdersProvider(sessionId)` | Phiên và đơn của phiên. |
| `ordersByStatusesProvider(statuses)` | Hàng đợi order theo trạng thái; truyền list ổn định/const để tránh tạo stream family liên tục. |
| `menuItemsProvider` | Stream menu sắp xếp theo tên. |
| `reservationByIdProvider(id)` | Theo dõi một reservation cụ thể. |

Lưu ý: trong source provider, `appConfigProvider`, `menuItemsProvider`, `reservationByIdProvider` truy vấn Firestore trực tiếp **bên trong package core**. Điều này vẫn giữ UI app không truy cập Firestore trực tiếp, nhưng cần cân nhắc đưa các truy vấn này vào service nếu muốn tập trung toàn bộ data access ở service.

## Rules, indexes và giới hạn bảo mật cần biết

- `firebase/firestore.rules` cho phép user đã đăng nhập đọc rộng một số collection; customer được tạo reservation/session/request, và cập nhật một số tài liệu theo owner. Rules hiện không buộc mọi field/status transition phải hợp lệ ở server. Một số quyền rộng (ví dụ slot write cho authenticated users, session create/update) cần được rà soát; route guard/UI không phải ranh giới bảo mật.
- Rules trong repo cần deploy và kiểm thử rules riêng. Cấu hình hiện tại không chứng minh production đã áp dụng.
- `firebase/firestore.indexes.json` khai báo composite indexes cho order collection group, reservation, session và request queries. Việc có file không đồng nghĩa indexes đã build xong trên Firebase.
- Firebase client API key không thay thế Security Rules; không đưa service-account key hoặc mật khẩu vào repo.

## Tài liệu liên quan

- [PROJECT_SPEC.md](../PROJECT_SPEC.md): yêu cầu hệ thống, schema và hợp đồng liên-app.
- [TEAM_DEMO_DATA.md](TEAM_DEMO_DATA.md): hướng dẫn dữ liệu demo dùng chung.
- `packages/core/lib/services/` và `packages/core/lib/providers/core_providers.dart`: nguồn chữ ký/mã nguồn chuẩn.
