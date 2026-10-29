# PROJECT SPECIFICATION: CAFE TABLE & ORDER MANAGEMENT SYSTEM

> **Đặc tả làm việc cập nhật ngày 29/10/2026, đối chiếu mã nguồn hiện tại.**
> Tài liệu phân biệt yêu cầu cần hoàn thành và chức năng đã triển khai tại Mục 8. Các thay đổi mới trong working tree chỉ có trên máy cho đến khi được commit/push.
> **Nguyên tắc tối thượng cho AI:** Luôn đọc kỹ cấu trúc Monorepo, Schema Firestore, Chữ ký hàm (Method Signatures) trong `packages/core` và Quy tắc phân vùng code của 3 thành viên trước khi sinh bất kỳ dòng code nào.

---

## 1. TỔNG QUAN & TECH STACK

- **Mục tiêu hệ thống:** Giải quyết 2 bài toán cho quán Cafe:
  1. **Rút ngắn thời gian đặt món:** Đặt trước qua App (Pre-order), sinh mã QR đơn hàng để quầy POS quét 1 chạm, hoặc nhân viên đặt hộ nhanh tại bàn.
  2. **Nhắc nhở việc ngồi lâu (Xoay vòng bàn):** Mặc định mỗi phiên ngồi 120 phút. Đồng hồ đếm ngược đồng bộ theo giờ Server, báo rung/thông báo ở các mốc 15', 5', 0', hỗ trợ gia hạn (nếu không vướng lịch đặt sau), trả bàn sớm nhận điểm thưởng, và nhân viên gửi yêu cầu nhả bàn.
- **Tech Stack:**
  - **Framework:** Flutter (Dart 3.x+, Null Safety bắt buộc).
  - **Kiến trúc:** Monorepo gồm 1 package `core` và 3 ứng dụng (`customer_app`, `waiter_app`, `counter_app`). Hiện các app dùng dependency đường dẫn tới core; chưa cấu hình Pub Workspaces/Melos.
  - **State Management & Routing:** `flutter_riverpod`, `go_router`.
  - **Backend:** Firebase Authentication, Cloud Firestore (Real-time Streams & Transactions).
  - **Packages bắt buộc:** `cloud_firestore`, `firebase_auth`, `flutter_local_notifications`, `timezone`, `vibration`, `mobile_scanner`, `qr_flutter`, `intl`.

---

## 2. CẤU TRÚC THƯ MỤC MONOREPO & QUY TẮC PHÂN VÙNG (CHỐNG CONFLICT GIT)

```text
cafe_system/
├── pubspec.yaml                  # Package gốc; chưa cấu hình Workspace / Melos
├── PROJECT_SPEC.md               # File tài liệu thiết kế gốc này
├── firebase/
│   ├── firestore.rules           # Phụ trách: TRƯỜNG
│   └── firestore.indexes.json    # Phụ trách: TRƯỜNG
├── packages/
│   └── core/                     # GÓI DÙNG CHUNG CHO CẢ 3 APP
│       ├── pubspec.yaml
│       └── lib/
│           ├── core.dart         # Barrel file export toàn bộ core
│           ├── constants/        # app_config.dart, enums.dart (TRƯỜNG)
│           ├── models/           # user_model.dart, table_model.dart, menu_item_model.dart,
│           │                     # reservation_model.dart, session_model.dart, order_model.dart,
│           │                     # request_model.dart, payment_model.dart (TRƯỜNG)
│           ├── services/         # clock_service.dart, auth_service.dart, reservation_service.dart,
│           │                     # session_service.dart, order_service.dart, payment_service.dart,
│           │                     # alarm_service.dart, seed_service.dart (TRƯỜNG)
│           ├── providers/        # Riverpod providers dùng chung (TRƯỜNG)
│           ├── theme/            # app_colors.dart, app_theme.dart (DƯƠNG)
│           └── widgets/          # countdown_timer_widget.dart, status_badge.dart (DƯƠNG)
└── apps/
    ├── counter_app/              # Ứng dụng Quầy POS / Quản lý -> CHỈ TRƯỜNG ĐƯỢC SỬA
    ├── customer_app/             # Ứng dụng Khách hàng        -> CHỈ DƯƠNG ĐƯỢC SỬA
    └── waiter_app/               # Ứng dụng Nhân viên Phục vụ -> CHỈ TRUNG ĐƯỢC SỬA
```

**QUY TẮC BẮT BUỘC CHO AI AGENT:**
Không gọi Firestore trực tiếp ở UI: Các màn hình trong apps/customer_app, apps/waiter_app, apps/counter_app TUYỆT ĐỐI KHÔNG import cloud_firestore để tự gọi .collection(...).add/update. Mọi thao tác đọc/ghi phải gọi qua các Service/Provider nằm trong packages/core.

Tuân thủ phạm vi thư mục:

Khi code cho Trường: Chỉ sửa trong packages/core/lib/(constants|models|services|providers), firebase/, và apps/counter_app/.

Khi code cho Dương: Chỉ sửa trong packages/core/lib/(theme|widgets) và apps/customer_app/.

Khi code cho Trung: Chỉ sửa trong apps/waiter_app/.

Đồng bộ giờ Server: Tuyệt đối không dùng DateTime.now() trực tiếp để tính giờ hết hạn phiên. Luôn dùng ClockService.instance.serverNow.

## 3. CẤU HÌNH NGHIỆP VỤ & ENUMS (packages/core/lib/constants/)

### 3.1. Document config/app (Class AppConfig)
Nếu trên Firestore chưa có document config/app, sử dụng giá trị mặc định sau:

sessionMinutes: 120 (Thời lượng tiêu chuẩn 1 phiên bàn)

extendStepMinutes: 30 (Mỗi lần gia hạn cộng thêm 30 phút)

warnMinutes: [15, 5] (Các mốc cảnh báo trước khi hết giờ)

reservationHoldMinutes: 15 (Giữ bàn tối đa 15 phút sau giờ hẹn, quá giờ tính no_show)

bufferMinutes: 15 (Khoảng đệm giữa 2 phiên để dọn bàn)

checkInEarlyMinutes: 15 (Cho phép check-in sớm tối đa 15 phút trước giờ hẹn)

minAdvanceMinutes: 30 (Đặt bàn trước tối thiểu 30 phút)

maxAdvanceDays: 7 (Đặt bàn trước tối đa 7 ngày)

pointEarnVnd: 10000 (10.000đ = 1 điểm tích lũy)

pointRedeemVnd: 1000 (1 điểm = 1.000đ giảm giá)

maxRedeemPercent: 50 (Dùng điểm giảm tối đa 50% hóa đơn)

earlyReleaseMinMinutes: 30 (Trả bàn sớm khi còn >= 30 phút được thưởng điểm)

earlyReleaseBonusPoints: 20 (Thưởng 20 điểm khi trả bàn sớm hợp lệ)

preOrderBonusPoints: 10 (Thưởng 10 điểm khi có đặt món trước)

Các con số trên là giá trị mặc định, không phải hằng số bắt buộc cho mọi lần chạy. Service đọc cấu hình khi thực hiện nghiệp vụ. Lưu cấu hình không sửa lại `expiresAt` của phiên đang mở.

`AppConfig.validate()` yêu cầu các giá trị hợp lệ: số nguyên không âm; thời lượng phiên, bước gia hạn, số ngày đặt trước, đơn giá tích/đổi điểm và ngưỡng trả sớm phải dương; phần trăm đổi điểm từ 0 đến 100; `sessionMinutes + bufferMinutes <= 150` để phù hợp 5 slot; danh sách cảnh báo không rỗng, không trùng, dương và nhỏ hơn thời lượng phiên; thời gian đặt trước tối thiểu không vượt khoảng đặt trước tối đa.

### 3.2. Các Enum chuẩn (enums.dart)
UserRole: customer, waiter, counter, manager

TablePhysicalStatus: available, occupied, needs_cleaning

TableDisplayStatus (Tính trên client): free, reservedSoon, using, expiring, overtime, cleaning

ReservationStatus: confirmed, checked_in, no_show, cancelled, completed

SessionStatus: active, billing, paid, cancelled

OrderStatus: pending, confirmed, preparing, ready, served, cancelled

OrderType: dine_in, takeaway

RequestType: call_waiter, request_bill, release_table, early_release

PaymentMethod: cash, qr, card

## 4. MÔ HÌNH DỮ LIỆU FIRESTORE (packages/core/lib/models/)

Cả ba app dùng chung Firebase project `cafe-73637`, database `(default)`. Không tạo database hoặc bộ collection riêng theo từng app. ID model lấy từ document ID khi đọc; không yêu cầu mọi document phải chứa trường `id`. DateTime được lưu dạng Firestore Timestamp.
Tất cả các Model phải có fromMap(Map<String, dynamic> map, String id), toMap(), và copyWith().

users/{uid} (UserModel)

id: String, role: String, displayName: String, phone: String, email: String, points: int, fcmTokens: List, createdAt: DateTime.

Subcollection users/{uid}/pointTx/{txId} (PointTxModel): type ('earn'|'redeem'|'bonus_early_release'|'bonus_preorder'), points: int, sessionId: String, at: DateTime.

tables/{tableId} (TableModel)

id: String, name: String (VD: "Bàn 01"), zone: String (VD: "Tầng 1"), capacity: int, status: String (available | occupied | needs_cleaning), currentSessionId: String?, qrSecret: String.

Định dạng QR dán tại bàn: cafe://table/{tableId}?k={qrSecret}

Subcollection tables/{tableId}/slots/{yyyyMMddHHmm} (TableSlotModel):

reservationId: String, resStart: Timestamp. (Mỗi reservation giữ 5 slot liên tiếp cách nhau 30 phút = 150 phút).

menuItems/{itemId} (MenuItemModel)

id: String, name: String, price: int, category: String, imageUrl: String, available: bool.

options: List (mỗi group có groupName, required: bool, maxSelect: int, choices: List<{name: String, extraPrice: int}>).

reservations/{resId} (ReservationModel)

id: String, customerId: String, customerName: String, phone: String, tableId: String, tableName: String, partySize: int.

startTime: DateTime, endTime: DateTime, holdUntil: DateTime.

status: String (confirmed | checked_in | no_show | cancelled | completed).

preOrderItems: List ({itemId, name, unitPrice, qty, selectedOptions, note}).

sessionId: String?, createdAt: DateTime.

Định dạng QR đơn đặt trước: cafe://preorder/{resId}

sessions/{sessionId} (SessionModel)

id: String, tableId: String, tableName: String, customerId: String?, customerName: String, guestPhone: String?.

openedBy: String, openedByRole: String, reservationId: String?.

startedAt: DateTime, baseMinutes: int, extendedMinutes: int, expiresAt: DateTime.

extensions: List<Map<String, dynamic>> ([{at, minutes, by}]).

earlyReleased: bool, status: String (active | billing | paid | cancelled), subtotal: int.

sessions/{sessionId}/orders/{orderId} (OrderModel)

id: String, sessionId: String, tableId: String, tableName: String.

items: List, createdBy: String, createdByRole: String.

type: String (dine_in | takeaway), status: String (pending | confirmed | preparing | ready | served | cancelled).

cancelReason: String?, total: int, createdAt: DateTime, updatedAt: DateTime.

Đơn mang đi chỉ lưu tại `sessions/takeaway_orders/orders/{orderId}`, với `sessionId = takeaway_orders`, `tableId = takeaway`. Không dùng collection `takeawayOrders`. Document cha `sessions/takeaway_orders` không phải phiên ngồi bàn và có thể không tồn tại.

`OrderModel.paymentId: String?` là trường bổ sung tương thích dữ liệu cũ, liên kết thanh toán của đơn mang đi. Thiếu/null nghĩa là chưa thanh toán; trạng thái `served` không chứng minh đã thu tiền.

requests/{reqId} (RequestModel)

id: String, sessionId: String, tableId: String, tableName: String.

type: String (call_waiter | request_bill | release_table | early_release), message: String, status: String (open | done), createdBy: String, createdAt: DateTime.

payments/{payId} (PaymentModel)

id: String, sessionId: String, tableId: String, tableName: String, cashierId: String, method: String (cash | qr | card).

subtotal: int, pointsUsed: int, discount: int, total: int, pointsEarned: int, bonusPoints: int, customerId: String?, paidAt: DateTime.

### 4.1. Các trường bổ sung và khả năng tương thích

- `payments/{payId}.items`: snapshot danh sách món tại lúc thanh toán; đọc bằng `PaymentService.getPaymentItems()`. `PaymentModel` chưa ánh xạ trường này. Hóa đơn cũ có thể thiếu snapshot.
- `payments/{payId}.orderId`: tùy chọn, dùng cho đơn mang đi. ID payment mang đi là `takeaway_{orderId}` để chống thu tiền trùng.
- `users/{uid}/pointTx/{txId}.paymentId`: tùy chọn để đối chiếu giao dịch. Điểm trong log có dấu cộng/trừ theo nghiệp vụ.
- `sessions/{sessionId}.orderRevision`: metadata tùy chọn do service cập nhật để phát hiện xung đột giữa gửi đơn và thanh toán; UI không tự ghi.
- `demoBatch` và ghi chú dữ liệu mẫu là metadata tùy chọn, không thay thế trường nghiệp vụ.
- Không đổi tên collection, enum hoặc biến trường bổ sung thành bắt buộc nếu chưa thống nhất với hai app còn lại.

## 5. CHỮ KÝ HÀM CHUẨN TRONG packages/core/lib/services/ (CONTRACT)

Các service đã có trong core. Danh sách dưới đây cùng phần bổ sung 5.9 là hợp đồng cho Dương và Trung; khi gọi phải đối chiếu chữ ký thực tế trong source.

5.1. ClockService
Future<void> syncClock(String uid)

DateTime get serverNow

5.2. AuthService
Stream<UserModel?> watchCurrentUser()

Future<UserModel> signInWithEmail(String email, String password, {required List<UserRole> allowedRoles})

Future<UserModel> registerCustomer({required String email, required String password, required String displayName, required String phone})

Future<void> signOut()

Future<UserModel?> findCustomerByPhone(String phone)

5.3. ReservationService
Future<List<TableModel>> getAvailableTables({required DateTime startTime, required int partySize})

Future<String> createReservation(ReservationModel draft) (Chạy Transaction kiểm tra & khóa 5 ô slots/{yyyyMMddHHmm})

Future<void> cancelReservation(String reservationId) (Chạy Transaction hủy & xóa 5 ô slots)

Future<int> sweepNoShows() (Quét các reservation confirmed quá holdUntil -> chuyển no_show và giải phóng slots)

Stream<List<ReservationModel>> watchCustomerReservations(String customerId)

Stream<List<ReservationModel>> watchTodayConfirmedReservations()

5.4. SessionService
TableDisplayStatus computeDisplayStatus(TableModel table, SessionModel? activeSession, ReservationModel? nextRes, DateTime now, {AppConfig config = AppConfig.defaultConfig})

Future<String> openSession({required String tableId, String? customerId, String customerName = 'Khách vãng lai', required String openedBy, required String openedByRole, String? reservationId})
(Transaction: Kiểm tra bàn available, cắt thời lượng nếu vướng slots đặt sau, tạo session, đổi bàn sang occupied, nếu có reservationId thì chuyển reservation sang checked_in và tự động tạo Order đầu tiên từ preOrderItems — trạng thái confirmed nếu openedByRole != 'customer', ngược lại pending).

Future<String> checkInByTableQr({required String qrContent, required String customerId, String? reservationId})

Future<String> checkInByPreOrderQrAtCounter({required String qrContent, required String counterUid, String? assignTableId})

Future<int> extendSession(String sessionId, {required String byUid}) (Transaction: Cộng extendStepMinutes hoặc tối đa tới nextRes.startTime - bufferMinutes, tối thiểu 10 phút).

Future<void> requestEarlyRelease(String sessionId, {required String customerId}) (Kiểm tra thời gian còn lại >= earlyReleaseMinMinutes, đặt earlyReleased = true, status = 'billing', tạo Request early_release).

Future<void> switchTable({required String sessionId, required String newTableId, bool oldTableNeedsCleaning = true})

Future<void> cancelMistakenSession(String sessionId)

Chỉ hủy phiên active/billing chưa có subtotal hoặc đơn chưa hủy, bàn còn trỏ đúng phiên. Nếu liên kết reservation, hủy lịch và giải phóng đúng các slot còn thuộc lịch đó, kể cả sau chuyển bàn. Không cho hủy phiên paid hoặc giải phóng bàn đang thuộc phiên khác.

Future<void> markTableCleaned(String tableId)

Future<void> sendTableRequest({required String sessionId, required String tableId, required String tableName, required RequestType type, required String createdBy, String message = ''})

Future<void> resolveRequest(String requestId)

5.5. OrderService
Future<String> submitOrder({required String sessionId, required String tableId, required String tableName, required List<OrderItemModel> items, required String createdBy, required String createdByRole, OrderType type = OrderType.dine_in})
(Đọc lại menuItems để kiểm tra available == true và lấy đúng giá server. Nếu createdByRole == 'customer' -> status = 'pending'. Nếu nhân viên/quầy tạo -> status = 'confirmed' và cộng ngay total vào sessions.subtotal).

Future<void> approveOrder(String sessionId, String orderId) (Chuyển pending -> confirmed, cộng total vào sessions.subtotal).

Future<void> cancelOrder(String sessionId, String orderId, {required String reason}) (Trừ subtotal nếu đơn đã được tính tiền tạm tính: confirmed/preparing/ready/served; pending không trừ. Service chặn sửa phiên đã đóng và hủy đơn mang đi đã thanh toán).

Future<void> updatePreparationStatus(String sessionId, String orderId, OrderStatus newStatus) (confirmed -> preparing -> ready -> served).

Stream<List<OrderModel>> watchSessionOrders(String sessionId)

Stream<List<OrderModel>> watchAllOrdersByStatuses(List<OrderStatus> statuses) (Dùng collectionGroup('orders')).

5.6. PaymentService
Future<PaymentModel> payAndClose({required String sessionId, required String cashierId, required PaymentMethod method, String? customerId, int pointsUsed = 0, int? expectedSubtotal, AppConfig? expectedConfig})
(Transaction: Kiểm tra không còn đơn pending, tính giảm giá tối đa 50%, cộng điểm tích lũy + điểm thưởng earlyReleased + điểm thưởng preOrder, tạo payments, ghi log pointTx, đổi session -> paid, đổi table -> needs_cleaning, giải phóng các slots tương lai).

5.7. AlarmService
Quản lý flutter_local_notifications + Vibration.

Dùng Map<String, Set<int>> firedBySession = {} để theo dõi độc lập các mốc [15, 5, 0] phút của từng sessionId (đảm bảo máy Phục vụ và Quầy theo dõi 20 bàn cùng lúc không bị nuốt thông báo).

Hàm `Future<void> syncAlarmsForSession(SessionModel s, {AppConfig config = AppConfig.defaultConfig})` và `void onTickCheck(List<SessionModel> activeSessions, {AppConfig config = AppConfig.defaultConfig})`. Các app truyền cấu hình hiện tại để đổi ngưỡng cảnh báo; mốc hết giờ là 0. Trạng thái đã báo được theo dõi riêng trên từng thiết bị.

5.8. SeedService
Future<void> seedInitialDataIfEmpty(): Tạo config/app nếu thiếu, 12 bàn mẫu nếu collection bàn rỗng, 10 món mẫu nếu collection menu rỗng. Không tự tạo tài khoản Firebase Authentication, không tự đặt lại ngày dữ liệu demo và không ghi đè dữ liệu hiện có.

### 5.9. API bổ sung đang có

```dart
// AuthService: chỉ trả về thành viên role customer hợp lệ.
Future<UserModel?> findCustomerById(String uid);

// ConfigService: validate; expected giúp phát hiện người khác vừa sửa cấu hình.
Future<AppConfig> read({Transaction? transaction});
Future<void> save(AppConfig config, {AppConfig? expected});

// PaymentService
static PaymentCalculationResult calculatePayment({
  required int subtotal, int pointsUsed = 0,
  bool earlyReleased = false, bool hasPreOrder = false,
  AppConfig config = AppConfig.defaultConfig,
});
Future<PaymentModel> payTakeaway({
  required String orderId, required String cashierId,
  required PaymentMethod method, String? customerId, int pointsUsed = 0,
  int? expectedSubtotal, AppConfig? expectedConfig,
});
Future<List<OrderItemModel>> getPaymentItems(String paymentId);
Stream<PaymentModel?> watchSessionPayment(String sessionId);
Stream<List<PaymentModel>> watchTodayPayments();

// SessionService
Stream<SessionModel?> watchSession(String sessionId);
Stream<List<SessionModel>> watchActiveSessions();
Stream<List<TableModel>> watchAllTables();
Stream<List<RequestModel>> watchOpenRequests();
Stream<List<SessionModel>> watchTodaySessions();

// ReservationService / OrderService
Stream<List<ReservationModel>> watchTodayNoShows();
Future<void> toggleMenuItemAvailability(String itemId, bool available);
```

`ConfigService.save` bảo toàn các trường cấu hình lạ khi merge. Các tham số mới là tùy chọn nhằm giữ các lời gọi cũ hoạt động.

Providers dùng chung: `currentUserProvider`, `appConfigProvider`, `allTablesProvider`, `activeSessionsProvider`, `openRequestsProvider`, `todayConfirmedReservationsProvider`, `todayNoShowsProvider`, `todaySessionsProvider`, `todayPaymentsProvider`, `menuItemsProvider`; các family `customerReservationsProvider`, `reservationByIdProvider`, `sessionStreamProvider`, `sessionOrdersProvider`, `ordersByStatusesProvider`. Khi gọi family bằng danh sách trạng thái, dùng danh sách const hoặc tham số ổn định, tránh tạo List mới mỗi lần build gây đăng ký stream liên tục.

### 5.10. Quy tắc thanh toán và liên thông ba app

1. Đơn do khách gửi là `pending`; duyệt đơn chuyển `confirmed` và cộng subtotal. Đơn do nhân viên/quầy tạo vào `confirmed`.
2. Luồng phục vụ: `confirmed -> preparing -> ready -> served`. **Đã phục vụ không đồng nghĩa đã thanh toán**, không làm tăng doanh thu.
3. Thanh toán tại bàn dùng `payAndClose`: transaction kiểm tra phiên active/billing, bàn vẫn trỏ đúng phiên, không còn đơn pending, tính lại món hợp lệ và kiểm tra thành viên/điểm/cấu hình. Khi thành công: lưu payment và snapshot, ghi điểm, phiên paid, bàn needs_cleaning, hoàn thành lịch đặt và giải phóng slot thuộc đúng lịch đặt. Phiên đã trả tiền không được trả lần hai.
4. `expectedSubtotal`/`expectedConfig` chặn chốt tiền khi bản xem trước đã cũ. UI cần tải lại và yêu cầu xác nhận số tiền mới khi có thay đổi.
5. Đổi điểm theo số điểm nguyên, không vượt tỷ lệ cấu hình và số dư thành viên. Điểm tích lũy tính theo tiền thực trả. Thưởng preorder chỉ khi reservation có món đặt trước, không chỉ vì có reservationId.
6. Đơn mang đi dùng `payTakeaway`, chỉ khi ready/served. Thu tiền không đổi trạng thái phục vụ và không đóng bàn. Ready đã trả vẫn chờ giao; served chưa trả vẫn chờ thanh toán; served đã trả mới rời hàng đợi xử lý.
7. `cash`, `qr`, `card` hiện là phương thức nhân viên xác nhận thủ công; chưa tích hợp cổng thanh toán hoặc xác nhận giao dịch ngân hàng tự động.
8. `sweepNoShows()` phải được gọi để cập nhật no-show; hiện chưa có lịch chạy backend tự động. Không giả định Firestore tự đổi trạng thái khi quá giờ.

## 6. PHÂN CÔNG CHI TIẾT MÀN HÌNH CHO 3 THÀNH VIÊN
PHẦN A — TRƯỜNG (packages/core, firebase/, và apps/counter_app)
Xây dựng toàn bộ packages/core (Constants, Models, Services, Providers) và firebase/ (firestore.rules, firestore.indexes.json).

Xây dựng apps/counter_app (Tối ưu giao diện Tablet/Desktop ngang - Responsive):

CounterAuthScreen: Đăng nhập dành cho counter / manager.

PosDashboardScreen: Màn hình chính chia cột:

Cột 1: Sơ đồ bàn tổng quan (màu theo TableDisplayStatus, đồng hồ đếm ngược, cảnh báo bàn chờ thanh toán billing).

Cột 2: Hàng đợi pha chế (OrderQueuePanel: chuyển trạng thái confirmed -> preparing -> ready) & tạo đơn Mang đi (Takeaway).

Cột 3: Chi tiết hóa đơn của bàn đang chọn & Thông báo requests.

UniversalQrScannerDialog: Quét mã QR đơn đặt trước (cafe://preorder/{resId} -> tự động mở bàn & duyệt đơn ngay), quét QR bàn, hoặc quét QR thành viên (cafe://member/{uid}).

PaymentCheckoutModal: Chọn thành viên (quét QR hoặc tìm SĐT), nhập số điểm đổi, hiển thị điểm thưởng nhận được, chọn phương thức (cash, qr, card), chốt thanh toán và xem hóa đơn trên màn hình (InvoicePreviewDialog). SavedInvoiceDialog mở lại snapshot hóa đơn đã lưu, không chạy thanh toán lần nữa. Demo dùng 3 laptop, không yêu cầu máy in/in hóa đơn vật lý.

ManagerAdminScreen: Bật/tắt món available, chỉnh sửa thông số config/app, nút chạy SeedService, và thống kê doanh thu/số phiên/no-show trong ngày.

PHẦN B — DƯƠNG BÙI (packages/core/lib/theme|widgets và apps/customer_app)
### Phạm vi và trạng thái đối chiếu mã nguồn (19/10/2026)

Phạm vi sửa của Dương gồm `packages/core/lib/theme/`, `packages/core/lib/widgets/` và `apps/customer_app/`. Không sửa schema/service/provider/rules thuộc Phần A; nếu thiếu nghiệp vụ, ghi đề xuất API để nhóm thống nhất. Mọi truy cập dữ liệu phải đi qua core service/provider, không gọi Firestore trực tiếp trong màn hình.

**Đã có trong core:** `AppColors`, `AppTheme`, `CountdownTimerWidget`, `StatusBadge` và barrel export. Countdown nhận thời điểm hết hạn, màu/ngưỡng cảnh báo và callback gia hạn; ứng dụng phải truyền cấu hình hiện tại thay vì dựa vào ngưỡng mặc định. Các API tích hợp nằm ở `docs/BACKEND_API.md`.

**Trạng thái triển khai customer_app (22/10/2026):** đã có đăng nhập/đăng ký email, Google, đặt lại mật khẩu, hồ sơ/điểm, QR thành viên, menu, đặt và hủy bàn, danh sách đặt bàn, check-in bằng payload QR, phiên đang dùng với countdown/gia hạn/trả sớm/gọi phục vụ/yêu cầu hóa đơn và gửi món đơn giản. Lỗi stream hồ sơ sau khi Auth đã logout được xử lý bằng cách đưa UI về màn hình đăng nhập khi UID hiện tại đã nul  l.

### Màn hình và hành vi cần hoàn thành

Ứng dụng tối ưu mobile dọc, tuân thủ MVVM + Service/Repository, có trạng thái loading/error/empty và phản hồi lỗi quyền/mạng. Các class/màn hình chính có DartDoc như Mục 7. Không để Firebase CRUD trong widget.

1. **CustomerAuthScreen:** đăng nhập qua `AuthService.signInWithEmail(... allowedRoles: [UserRole.customer])`; đăng ký qua `registerCustomer`; khôi phục trạng thái qua `currentUserProvider`; đăng xuất qua `signOut`. Không dùng đăng nhập giả khi Firebase lỗi.
2. **CustomerHomeScreen:** thẻ thành viên, điểm, QR `cafe://member/{uid}`, phiên đang dùng nếu có, lối vào đặt bàn và quét QR. QR thành viên chỉ mang UID; quầy phải xác minh UID/role bằng AuthService, không tin dữ liệu QR như quyền xác thực.
3. **ReservationBookingScreen:** chọn thời gian, nhập số khách, gọi `getAvailableTables`, chọn bàn rồi `createReservation`; service kiểm tra giới hạn và transaction khóa slot. Hiển thị URI QR `cafe://preorder/{resId}` sau khi thành công. Chọn món/tùy chọn đặt trước chưa có UI.
4. **MyReservationsScreen:** dùng `customerReservationsProvider`, hiển thị lịch và QR; hủy qua `cancelReservation`; hỗ trợ đi đến luồng nhận bàn. Không tự sửa document reservation.
5. **TableQrScannerScreen:** hiện nhận URI QR nhập/dán và gọi `checkInByTableQr`; service kiểm tra định dạng, secret và trạng thái bàn. Camera permission có trong Android manifest nhưng app chưa tích hợp camera scanner/plugin.
6. **ActiveSessionScreen:** theo dõi session/orders, countdown theo core clock, khởi tạo/sync AlarmService, gia hạn, trả sớm, gọi phục vụ, yêu cầu thanh toán và gửi món chưa cần tùy chọn. UI món yêu cầu option bắt buộc đang được ẩn; các màn nhắc giờ nền theo mọi mốc config cần kiểm tra thêm trên thiết bị.
7. **PointsAndHistoryScreen:** lịch sử pointTx và thanh toán của khách hiện chưa có API stream chuyên biệt trong core. Đề xuất bổ sung API có kiểm soát quyền trước khi triển khai; không dùng truy vấn Firestore trực tiếp ở UI. Không hiển thị dữ liệu payment của khách khác.

**Còn thiếu để nghiệm thu:** PointsAndHistoryScreen (core chưa có API stream lịch sử an toàn), camera scanner thật, lựa chọn món/tùy chọn đặt trước, lựa chọn option khi gọi món, test widget CountdownTimerWidget/UI, Android Firebase options customer-specific và xác nhận quyền/rung/notification trên thiết bị thật.

### Tiêu chí hoàn thành Phần B

- `apps/customer_app` có cấu hình Flutter phụ thuộc `packages/core` và Firebase initialization cho project `cafe-73637`; cần bổ sung runner Android/customer-specific Firebase options và các màn hình nghiệp vụ trên.
- Có widget test cho CountdownTimerWidget theo Mục 7.2; kiểm tra đúng `HH:mm:ss`, màu cảnh báo khi đến ngưỡng cấu hình và callback/nút gia hạn. Kiểm tra/analyze/build theo quy trình nhóm trước khi nghiệm thu.
- Luồng đặt bàn, check-in, gọi món và yêu cầu thanh toán dùng đúng core contract; không ghi Firestore trực tiếp. Test UI nên mock/fake provider, không đụng dữ liệu Firebase demo chung.
- Cập nhật README customer_app với cách chạy và cấu hình platform; xác nhận quyền camera, rung, notification trên thiết bị thật trước khi tuyên bố nghiệm thu.

Chi tiết backend, tình trạng kết nối, schema, API và giới hạn xác minh được ghi tại [docs/BACKEND_API.md](docs/BACKEND_API.md).

PHẦN C — TRUNG (apps/waiter_app)
Xây dựng apps/waiter_app (Tối ưu thao tác nhanh 1 tay cho Nhân viên phục vụ):

WaiterAuthScreen: Đăng nhập dành cho waiter.

FloorMapScreen:

Lưới sơ đồ bàn theo khu vực (Zone), đổi màu realtime mỗi giây theo computeDisplayStatus, hiển thị đồng hồ đếm ngược ngay trên từng ô bàn.

Lắng nghe AlarmService để rung báo hiệu khi bất kỳ bàn nào chạm mốc 15', 5', 0' (đặc biệt cho khách vãng lai).

TableActionSheet (Khi bấm vào 1 bàn):

Nếu bàn available: Nút "Mở bàn khách vãng lai" và nút "Check-in hộ khách đặt trước".

Nếu bàn occupied: Xem thông tin phiên, nút "Đặt món hộ", "Gia hạn hộ (+30p)", "Chuyển bàn" (switchTable), "Yêu cầu nhả bàn" (release_table - bật khi bàn quá giờ hoặc sắp có khách đặt kế tiếp), và "Hủy phiên mở nhầm".

Nếu bàn needs_cleaning: Nút "Đã dọn xong" (markTableCleaned).

QuickOrderScreen: Giao diện chọn món siêu tốc bằng lưới ảnh + chọn nhanh ghi chú (Ít đá, Ít ngọt, Không kem...) -> Gửi đơn vào thẳng trạng thái confirmed.

WaiterTaskHubScreen (Màn hình xử lý tác vụ kèm Badge số lượng):

Tab 1: Duyệt đơn (pending) từ khách tự đặt -> Nút "Duyệt" (approveOrder) hoặc "Từ chối" kèm lý do (cancelOrder).

Tab 2: Món chờ bưng (ready) -> Nút "Đã mang ra bàn" (served).

Tab 3: Yêu cầu từ bàn (requests) -> Xử lý khách gọi phục vụ, khách báo trả bàn sớm, khách yêu cầu tính tiền.


---

### Hướng dẫn tiếp tục code

Không khởi tạo lại monorepo hoặc ghi đè core từ prompt cũ. Pull code đã thống nhất, đọc spec và chữ ký service thực tế. Mỗi người làm trên nhánh riêng; thay đổi API/schema phải thống nhất với nhóm và giữ tương thích dữ liệu cũ.

- **Trường:** Tiếp tục counter_app và core/firebase trong phạm vi phân công; báo rõ kiểm thử và giới hạn còn lại.
- **Dương:** Xây dựng customer_app cùng theme/widgets theo Phần B, dùng service/provider sẵn có và cùng Firebase project. Đọc appConfigProvider để hiển thị thời lượng/điểm động. Đề xuất API thiếu cho Trường, không tạo lại core.
- **Trung:** Xây dựng waiter_app theo Phần C, dùng đúng service/schema/status. Đã phục vụ chỉ cập nhật order, không tự ghi payment hoặc cộng doanh thu. Đề xuất API thiếu cho Trường.

---
## 7. YÊU CẦU BẮT BUỘC CỦA MÔN HỌC PRM393 (CODING STANDARDS, TESTING & RELEASE)

### 7.1. Kiến trúc MVVM + Repository Pattern & Code Comments
- Tất cả các màn hình trong 3 app phải tuân thủ mô hình **MVVM (Model - View - ViewModel/Notifier)** kết hợp **Repository/Service Pattern**.
- **Bắt buộc viết Comment (`///` DartDoc tiếng Việt hoặc tiếng Anh):** Mọi Model, Service, Repository, ViewModel và màn hình chính phải có comment giải thích mục đích của class, ý nghĩa tham số đầu vào và luồng xử lý để phục vụ chấm điểm mã nguồn.

### 7.2. Yêu cầu Unit Test & Widget Test (Bắt buộc cho cả 3 thành viên)
Mỗi thành viên phải có thư mục `test/` trong phạm vi của mình và chạy pass lệnh `flutter test`:
1. **Unit Tests (`packages/core/test/` - Phụ trách: TRƯỜNG):**
   - `session_display_status_test.dart`: Kiểm thử hàm `computeDisplayStatus` với đầy đủ 6 trạng thái (`free`, `reservedSoon`, `using`, `expiring`, `overtime`, `cleaning`).
   - `payment_calculation_test.dart`: Kiểm thử logic tính tiền, giới hạn giảm giá tối đa 50% hóa đơn khi đổi điểm (`maxRedeemPercent = 50`), cộng điểm tích lũy (`10.000đ = 1 điểm`), và cộng điểm thưởng trả bàn sớm (`earlyReleaseBonusPoints = 20`).
   - `slot_generation_test.dart`: Kiểm thử hàm `slotTimes(start)` sinh đúng 5 ô giữ chỗ liên tiếp cách nhau 30 phút.
2. **Widget Tests (Trong từng App của 3 thành viên):**
   - `apps/customer_app/test/countdown_timer_widget_test.dart` (**DƯƠNG BÙI**): Kiểm thử `CountdownTimerWidget` hiển thị đúng định dạng `HH:mm:ss`, đổi sang màu Cam khi còn <= 15 phút và hiện nút "Gia hạn +30 phút".
   - `apps/waiter_app/test/floor_map_tile_test.dart` (**TRUNG**): Kiểm thử ô bàn trên sơ đồ (`TableTileWidget`) hiển thị đúng tên bàn, màu sắc trạng thái và bật nút "Yêu cầu nhả bàn" khi bàn ở trạng thái `overtime`.
   - `apps/counter_app/test/payment_modal_test.dart` (**TRƯỜNG**): Kiểm thử giao diện thanh toán tự động giới hạn số điểm nhập vào không vượt quá 50% tổng tiền tạm tính.

### 7.3. Cấu hình Build Release APK
- Cấu hình sẵn `android/app/build.gradle` của cả 3 app (bật quyền `INTERNET`, `VIBRATE`, `CAMERA`, `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS` trong `AndroidManifest.xml`) để sẵn sàng chạy lệnh:
  `flutter build apk --release`

## 8. HIỆN TRẠNG TRIỂN KHAI VÀ NGHIỆM THU

### 8.1. Đã triển khai trong code hiện tại

- Core có models/services/providers cho đặt bàn, phiên bàn, món, yêu cầu, thanh toán, điểm và cấu hình động.
- Counter có sơ đồ bàn theo zone, hàng đợi, xử lý món, đơn mang đi, tra thành viên, thanh toán và hóa đơn đã lưu. Màn hình rộng từ 1200px dùng ba cột; màn hình nhỏ dùng ba tab. Có tải/lỗi/thử lại và chặn thao tác lặp khi đang xử lý.
- Manager có quản lý món, cấu hình, seed, thống kê trong ngày và mở lại hóa đơn. Route `/admin` chỉ cho manager; counter được chuyển về POS. Manager vẫn dùng được POS.
- Waiter đã có sơ đồ bàn, thao tác phiên, gọi món hộ, duyệt/giao món và xử lý yêu cầu; bổ sung nền tảng web cho demo laptop, cảnh báo trong giao diện, đăng nhập Firebase thật và thử lại khi khởi tạo lỗi. Hướng dẫn: [README waiter_app](apps/waiter_app/README.md).
- Customer từ main đã tích hợp vào nhánh làm việc: có cấu hình Firebase web, đăng nhập/đăng ký, đặt bàn và món trước, QR, phiên bàn/gọi thêm món, lịch sử điểm và hóa đơn. Chưa nghiệm thu luồng ba app trên nhiều máy thật.

### 8.2. Thống kê trong ngày

| Chỉ số | Nguồn và cách tính |
| --- | --- |
| Doanh thu | Tổng payments.total theo paidAt hôm nay |
| Số hóa đơn | Số payment trong cùng khoảng thời gian |
| Số phiên bắt đầu | Sessions theo startedAt hôm nay, bỏ cancelled và đơn mang đi |
| No-show | Reservations có status no_show và startTime hôm nay |

“Hôm nay” là từ 00:00 đến trước 00:00 ngày kế tiếp, theo đồng hồ đã đồng bộ và múi giờ máy; nhóm demo thống nhất Asia/Saigon. Dữ liệu hôm qua vẫn còn trong Firestore nhưng không được cộng vào hôm nay. Chưa có bộ lọc khoảng ngày. Chạy lại app không xóa lịch sử; seed không đổi ngày dữ liệu mẫu.

### 8.3. Firebase và dữ liệu demo chung

- Mỗi app cấu hình platform của mình trên cùng project `cafe-73637`. Tài khoản Google quản trị Console và tài khoản đăng nhập app có quyền riêng.
- Firebase Authentication UID phải khớp users/{uid} và role. SeedService không tạo tài khoản Auth; không giả định email ví dụ là tài khoản thật.
- Đã có batch `demo_team_20261018_v1` gồm bàn nhiều trạng thái, phiên, lịch đặt/slot, đơn, requests, payment và pointTx cho hai app còn lại phát triển theo. Xem [hướng dẫn dữ liệu nhóm](docs/TEAM_DEMO_DATA.md). Mốc ngày giờ cố định sẽ hết hạn tự nhiên.
- Không reset/xóa dữ liệu chung khi khởi động. Thêm/sửa dữ liệu dùng chung có thể thay đổi trạng thái bàn và thống kê trên máy khác.
- Không lưu mật khẩu, service-account key hoặc token trong spec/Git. Quyền dữ liệu thực tế phụ thuộc Firebase Auth và Firestore Rules.

### 8.4. Giới hạn cần xử lý trước khi tuyên bố hoàn thành

- Counter và waiter đều yêu cầu tài khoản Firebase thật; đã bỏ đăng nhập giả, tự tạo tài khoản/đổi role và anonymous dự phòng trong UI nhân viên.
- Customer tự check-in QR tại bàn vẫn bị Rules hiện tại chặn ghi tables. Luồng demo đã xác nhận dùng counter quét QR lịch đặt tại quầy. Không coi tự check-in là đã nghiệm thu.
- UI admin giới hạn manager nhưng rules cấu hình hiện vẫn cho manager/counter ghi. Cần thống nhất quyền và kiểm thử rules; route guard không thay thế kiểm soát backend.
- CountdownTimerWidget dùng chung đã bổ sung tham số warningMinutes/extendStepMinutes, mặc định 15/30 để giữ tương thích. Các app cần truyền cấu hình hiện tại khi hiển thị; không giả định mọi lời gọi cũ đã cập nhật ngưỡng động.
- Chưa nghiệm thu ba app trên ba máy thật, quyền camera/thông báo/rung, từ chối quyền, lỗi mạng và Firebase Rules.
- Android counter đã bổ sung scaffold/wrapper và cấu hình build nhưng APK release chưa xác nhận build thành công sau sự cố máy. Release signing hiện dùng debug key cho demo, chưa phải phát hành chính thức.

### 8.5. Kiểm thử đã ghi nhận

- Core: 39 test pass, gồm trạng thái, slot, điểm, checkout, cấu hình, transaction đặt bàn, gia hạn và hủy phiên.
- Counter: 26 test pass với `flutter test --concurrency=1`; `flutter analyze` pass; build web release thành công.
- Test mới gồm POS UX và nghiệp vụ liên vai trò dùng Firestore giả trong test. Đây chưa phải E2E ba UI thật hoặc kiểm thử rules đã triển khai.
- Waiter: 9 test pass, analyze không có góp ý; gồm bố cục laptop, cảnh báo, đăng nhập lỗi, chặn khách vào route phục vụ và lỗi stream phiên bàn. Bản web dùng cùng Firebase project với counter; vẫn cần thử luồng thực tế trên nhiều máy.
- Customer đã có countdown_timer_widget_test.dart và customer_viewmodels_test.dart. Chạy lại kiểm tra liên quan sau khi tích hợp core. Xem [README counter_app](apps/counter_app/README.md) và [README customer_app](apps/customer_app/README.md).
- Ngày 29/10: customer 10 test, counter 26, waiter 9, core 39 — tổng 84 test pass. Đã thử UI ba phiên web với Firebase thật, check-in tại quầy, gọi/duyệt/pha chế/phục vụ, thanh toán, điểm, lịch sử, dọn bàn, gia hạn và chuyển bàn. Kết quả, fixture và giới hạn: [DEMO_RUNBOOK.md](docs/DEMO_RUNBOOK.md).
- Sau tích hợp main ngày 28/10: customer analyze đạt và 8 test pass; core 32, counter 24, waiter 9 test đều pass trên cùng core mới. Chưa thay thế kiểm thử ba ứng dụng thật. Counter cần cập nhật dependency Google Sign-In; bước tạo symlink Windows native yêu cầu Developer Mode trên máy hiện tại, còn test có thể chạy với `--no-pub` sau khi dependency đã được resolve.

### 8.6. Checklist tích hợp ba laptop

1. Đồng bộ code/core đã commit, cùng Firebase project, tài khoản thật đúng role.
2. Customer đặt bàn có món trước; counter/waiter check-in; đối chiếu phiên/slot/món.
3. Customer gửi món pending; waiter duyệt; counter pha chế; waiter đánh dấu served; doanh thu chưa tăng.
4. Counter thanh toán một lần; đối chiếu payment, điểm/log, phiên paid, bàn needs_cleaning; waiter dọn về available.
5. Thử mang đi ready/served trước và sau thanh toán; mở lại hóa đơn không thu tiền lại.
6. Thử đồng thời sửa cấu hình/gửi đơn/thanh toán, lỗi mạng, thiếu quyền và đổi ngày. Chỉ đánh dấu nghiệm thu khi có kết quả thực tế.
