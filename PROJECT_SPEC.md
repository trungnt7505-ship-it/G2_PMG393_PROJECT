# PROJECT SPECIFICATION: CAFE TABLE & ORDER MANAGEMENT SYSTEM

> **Tài liệu gốc dành cho AI Coding Agent (Antigravity).**
> **Nguyên tắc tối thượng cho AI:** Luôn đọc kỹ cấu trúc Monorepo, Schema Firestore, Chữ ký hàm (Method Signatures) trong `packages/core` và Quy tắc phân vùng code của 3 thành viên trước khi sinh bất kỳ dòng code nào.

---

## 1. TỔNG QUAN & TECH STACK

- **Mục tiêu hệ thống:** Giải quyết 2 bài toán cho quán Cafe:
  1. **Rút ngắn thời gian đặt món:** Đặt trước qua App (Pre-order), sinh mã QR đơn hàng để quầy POS quét 1 chạm, hoặc nhân viên đặt hộ nhanh tại bàn.
  2. **Nhắc nhở việc ngồi lâu (Xoay vòng bàn):** Mặc định mỗi phiên ngồi 120 phút. Đồng hồ đếm ngược đồng bộ theo giờ Server, báo rung/thông báo ở các mốc 15', 5', 0', hỗ trợ gia hạn (nếu không vướng lịch đặt sau), trả bàn sớm nhận điểm thưởng, và nhân viên gửi yêu cầu nhả bàn.
- **Tech Stack:**
  - **Framework:** Flutter (Dart 3.x+, Null Safety bắt buộc).
  - **Kiến trúc:** Monorepo (quản lý bằng Dart Pub Workspaces hoặc Melos) gồm 1 package `core` và 3 ứng dụng (`customer_app`, `waiter_app`, `counter_app`).
  - **State Management & Routing:** `flutter_riverpod`, `go_router`.
  - **Backend:** Firebase Authentication, Cloud Firestore (Real-time Streams & Transactions).
  - **Packages bắt buộc:** `cloud_firestore`, `firebase_auth`, `flutter_local_notifications`, `timezone`, `vibration`, `mobile_scanner`, `qr_flutter`, `intl`.

---

## 2. CẤU TRÚC THƯ MỤC MONOREPO & QUY TẮC PHÂN VÙNG (CHỐNG CONFLICT GIT)

```text
cafe_system/
├── pubspec.yaml                  # Cấu hình Workspace / Melos
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
    |
    QUY TẮC BẮT BUỘC CHO AI AGENT:
Không gọi Firestore trực tiếp ở UI: Các màn hình trong apps/customer_app, apps/waiter_app, apps/counter_app TUYỆT ĐỐI KHÔNG import cloud_firestore để tự gọi .collection(...).add/update. Mọi thao tác đọc/ghi phải gọi qua các Service/Provider nằm trong packages/core.

Tuân thủ phạm vi thư mục:

Khi code cho Trường: Chỉ sửa trong packages/core/lib/(constants|models|services|providers), firebase/, và apps/counter_app/.

Khi code cho Dương: Chỉ sửa trong packages/core/lib/(theme|widgets) và apps/customer_app/.

Khi code cho Trung: Chỉ sửa trong apps/waiter_app/.

Đồng bộ giờ Server: Tuyệt đối không dùng DateTime.now() trực tiếp để tính giờ hết hạn phiên. Luôn dùng ClockService.instance.serverNow.

3. HẰNG SỐ NGHIỆP VỤ & ENUMS (packages/core/lib/constants/)
3.1. Document config/app (Class AppConfig)
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

3.2. Các Enum chuẩn (enums.dart)
UserRole: customer, waiter, counter, manager

TablePhysicalStatus: available, occupied, needs_cleaning

TableDisplayStatus (Tính trên client): free, reservedSoon, using, expiring, overtime, cleaning

ReservationStatus: confirmed, checked_in, no_show, cancelled, completed

SessionStatus: active, billing, paid, cancelled

OrderStatus: pending, confirmed, preparing, ready, served, cancelled

OrderType: dine_in, takeaway

RequestType: call_waiter, request_bill, release_table, early_release

PaymentMethod: cash, qr, card

4. MÔ HÌNH DỮ LIỆU FIRESTORE (packages/core/lib/models/)
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

(Lưu ý: Đối với đơn mua mang đi takeaway không có bàn, lưu vào sessions/takeaway_orders/orders/{orderId} hoặc collection takeawayOrders/{orderId}).

requests/{reqId} (RequestModel)

id: String, sessionId: String, tableId: String, tableName: String.

type: String (call_waiter | request_bill | release_table | early_release), message: String, status: String (open | done), createdBy: String, createdAt: DateTime.

payments/{payId} (PaymentModel)

id: String, sessionId: String, tableId: String, tableName: String, cashierId: String, method: String (cash | qr | card).

subtotal: int, pointsUsed: int, discount: int, total: int, pointsEarned: int, bonusPoints: int, customerId: String?, paidAt: DateTime.

5. CHỮ KÝ HÀM CHUẨN TRONG packages/core/lib/services/ (CONTRACT)
Trường sẽ implement các class này. Dương và Trung chỉ việc gọi các hàm này từ UI/Provider:

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
TableDisplayStatus computeDisplayStatus(TableModel table, SessionModel? activeSession, ReservationModel? nextRes, DateTime now)

Future<String> openSession({required String tableId, String? customerId, String customerName = 'Khách vãng lai', required String openedBy, required String openedByRole, String? reservationId})
(Transaction: Kiểm tra bàn available, cắt thời lượng nếu vướng slots đặt sau, tạo session, đổi bàn sang occupied, nếu có reservationId thì chuyển reservation sang checked_in và tự động tạo Order đầu tiên từ preOrderItems — trạng thái confirmed nếu openedByRole != 'customer', ngược lại pending).

Future<String> checkInByTableQr({required String qrContent, required String customerId, String? reservationId})

Future<String> checkInByPreOrderQrAtCounter({required String qrContent, required String counterUid, String? assignTableId})

Future<int> extendSession(String sessionId, {required String byUid}) (Transaction: Cộng extendStepMinutes hoặc tối đa tới nextRes.startTime - bufferMinutes, tối thiểu 10 phút).

Future<void> requestEarlyRelease(String sessionId, {required String customerId}) (Kiểm tra thời gian còn lại >= earlyReleaseMinMinutes, đặt earlyReleased = true, status = 'billing', tạo Request early_release).

Future<void> switchTable({required String sessionId, required String newTableId, bool oldTableNeedsCleaning = true})

Future<void> cancelMistakenSession(String sessionId)

Future<void> markTableCleaned(String tableId)

Future<void> sendTableRequest({required String sessionId, required String tableId, required String tableName, required RequestType type, required String createdBy, String message = ''})

Future<void> resolveRequest(String requestId)

5.5. OrderService
Future<String> submitOrder({required String sessionId, required String tableId, required String tableName, required List<OrderItemModel> items, required String createdBy, required String createdByRole, OrderType type = OrderType.dine_in})
(Đọc lại menuItems để kiểm tra available == true và lấy đúng giá server. Nếu createdByRole == 'customer' -> status = 'pending'. Nếu nhân viên/quầy tạo -> status = 'confirmed' và cộng ngay total vào sessions.subtotal).

Future<void> approveOrder(String sessionId, String orderId) (Chuyển pending -> confirmed, cộng total vào sessions.subtotal).

Future<void> cancelOrder(String sessionId, String orderId, {required String reason}) (Nếu đơn đang confirmed thì trừ lại sessions.subtotal).

Future<void> updatePreparationStatus(String sessionId, String orderId, OrderStatus newStatus) (confirmed -> preparing -> ready -> served).

Stream<List<OrderModel>> watchSessionOrders(String sessionId)

Stream<List<OrderModel>> watchAllOrdersByStatuses(List<OrderStatus> statuses) (Dùng collectionGroup('orders')).

5.6. PaymentService
Future<PaymentModel> payAndClose({required String sessionId, required String cashierId, required PaymentMethod method, String? customerId, int pointsUsed = 0})
(Transaction: Kiểm tra không còn đơn pending, tính giảm giá tối đa 50%, cộng điểm tích lũy + điểm thưởng earlyReleased + điểm thưởng preOrder, tạo payments, ghi log pointTx, đổi session -> paid, đổi table -> needs_cleaning, giải phóng các slots tương lai).

5.7. AlarmService
Quản lý flutter_local_notifications + Vibration.

Dùng Map<String, Set<int>> firedBySession = {} để theo dõi độc lập các mốc [15, 5, 0] phút của từng sessionId (đảm bảo máy Phục vụ và Quầy theo dõi 20 bàn cùng lúc không bị nuốt thông báo).

Hàm Future<void> syncAlarmsForSession(SessionModel s) và void onTickCheck(List<SessionModel> activeSessions).

5.8. SeedService
Future<void> seedInitialDataIfEmpty(): Tự động tạo config/app, 12 bàn mẫu (Tầng 1, Tầng 2), 10 món nước/bánh mẫu kèm Topping/Size, và hướng dẫn tạo 3 tài khoản mẫu (customer@cafe.com, waiter@cafe.com, counter@cafe.com).

6. PHÂN CÔNG CHI TIẾT MÀN HÌNH CHO 3 THÀNH VIÊN
PHẦN A — TRƯỜNG (packages/core, firebase/, và apps/counter_app)
Xây dựng toàn bộ packages/core (Constants, Models, Services, Providers) và firebase/ (firestore.rules, firestore.indexes.json).

Xây dựng apps/counter_app (Tối ưu giao diện Tablet/Desktop ngang - Responsive):

CounterAuthScreen: Đăng nhập dành cho counter / manager.

PosDashboardScreen: Màn hình chính chia cột:

Cột 1: Sơ đồ bàn tổng quan (màu theo TableDisplayStatus, đồng hồ đếm ngược, cảnh báo bàn chờ thanh toán billing).

Cột 2: Hàng đợi pha chế (OrderQueuePanel: chuyển trạng thái confirmed -> preparing -> ready) & tạo đơn Mang đi (Takeaway).

Cột 3: Chi tiết hóa đơn của bàn đang chọn & Thông báo requests.

UniversalQrScannerDialog: Quét mã QR đơn đặt trước (cafe://preorder/{resId} -> tự động mở bàn & duyệt đơn ngay), quét QR bàn, hoặc quét QR thành viên (cafe://member/{uid}).

PaymentCheckoutModal: Chọn thành viên (quét QR hoặc tìm SĐT), nhập số điểm đổi, hiển thị điểm thưởng nhận được (thưởng trả bàn sớm / đặt trước), chọn phương thức (cash, qr, card), chốt thanh toán & xem bản in hóa đơn (InvoicePreviewDialog).

ManagerAdminScreen: Bật/tắt món available, chỉnh sửa thông số config/app, nút chạy SeedService, và thống kê doanh thu/số phiên/no-show trong ngày.

PHẦN B — DƯƠNG BÙI (packages/core/lib/theme|widgets và apps/customer_app)
Xây dựng packages/core/lib/theme/app_colors.dart (6 màu chuẩn cho 6 trạng thái TableDisplayStatus: Trống = Xanh lá, Sắp có khách đặt = Tím, Đang dùng = Xanh dương, Sắp hết giờ <=15p = Cam, Quá giờ = Đỏ, Chờ dọn = Xám) và countdown_timer_widget.dart.

Xây dựng apps/customer_app (Tối ưu giao diện Mobile dọc):

CustomerAuthScreen: Đăng nhập, Đăng ký tài khoản khách hàng.

CustomerHomeScreen: Hiển thị Thẻ thành viên + Điểm tích lũy + Mã QR thành viên (cafe://member/{uid}), Thẻ "Phiên bàn hiện tại" (nếu đang ngồi), nút "Đặt bàn & Đặt món trước", nút "Quét QR tại bàn".

ReservationBookingScreen: Chọn ngày/giờ (bước 30p), số người -> Lọc bàn trống -> Chọn món đặt trước (preOrderItems kèm Size/Topping) -> Xác nhận tạo đặt chỗ & Hiển thị mã QR Đơn đặt trước (cafe://preorder/{resId}) để đưa cho quầy hoặc dùng check-in tại bàn.

MyReservationsScreen: Danh sách lịch hẹn, xem mã QR đặt trước, hủy lịch hẹn, nút "Quét QR Nhận bàn".

TableQrScannerScreen: Quét mã QR tại bàn (cafe://table/{tableId}?k={qrSecret}) để Check-in lịch hẹn hoặc Tự mở bàn mới.

ActiveSessionScreen:

Đồng hồ đếm ngược lớn ở trung tâm, tự động rung Haptic (Vibration) và hiện Dialog khi chạm mốc 15', 5', 0' hoặc khi nhận request release_table từ nhân viên.

Nút "Gia hạn +30 phút" (sáng lên khi còn <= 15p) và nút "Trả bàn sớm (+20 điểm)" (khi còn >= 30p).

Tab gọi thêm món tại bàn (Menu -> Cart -> submitOrder) và theo dõi tiến độ món realtime (pending -> confirmed -> preparing -> ready -> served).

Nút "Gọi phục vụ" và "Yêu cầu thanh toán".

PointsAndHistoryScreen: Lịch sử cộng/trừ điểm (pointTx) và danh sách hóa đơn cũ.

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

### BƯỚC 2: Câu lệnh (Prompt) để từng người dán vào Antigravity

Sau khi lưu file `PROJECT_SPEC.md` vào thư mục gốc của project, các bạn làm theo đúng thứ tự sau:

#### 1. Prompt dành cho TRƯỜNG (Chạy đầu tiên để dựng Base + App Quầy)
*   **Lần chạy 1 (Dựng Base `packages/core` cho cả nhóm):**
    > `@PROJECT_SPEC.md Tôi là Trường. Hãy đọc kỹ tài liệu thiết kế. Bây giờ hãy khởi tạo cấu trúc Monorepo, tạo file firebase/firestore.rules, firebase/firestore.indexes.json và code hoàn chỉnh toàn bộ gói packages/core (bao gồm constants, models, services, providers và barrel file core.dart) đúng 100% với các chữ ký hàm đã quy định trong Mục 3, 4, 5. Tạo sẵn khung placeholder cho theme và widgets để không bị lỗi compile. Đảm bảo code chuẩn Null Safety, không có lỗi cú pháp.`
    *(Sau khi Antigravity chạy xong bước này, Trường push code lên Git để Dương và Trung pull về).*

*   **Lần chạy 2 (Code `apps/counter_app` của Trường):**
    > `@PROJECT_SPEC.md Tôi là Trường. Gói packages/core đã có sẵn. Bây giờ hãy code hoàn chỉnh ứng dụng apps/counter_app theo đúng đặc tả tại Mục 6 - PHẦN A (gồm CounterAuthScreen, PosDashboardScreen chia 3 cột, UniversalQrScannerDialog, PaymentCheckoutModal, InvoicePreviewDialog, và ManagerAdminScreen có nút Seed Data). Tuyệt đối chỉ sửa trong thư mục apps/counter_app và gọi dữ liệu thông qua packages/core.`

---

#### 2. Prompt dành cho DƯƠNG BÙI (Sau khi pull Base của Trường về)
> `@PROJECT_SPEC.md Tôi là Dương Bùi. Hãy đọc kỹ tài liệu thiết kế. Hãy thực hiện PHẦN B trong Mục 6:
> 1. Hoàn thiện packages/core/lib/theme/app_colors.dart, app_theme.dart và packages/core/lib/widgets/ (countdown_timer_widget.dart, status_badge.dart).
> 2. Code hoàn chỉnh ứng dụng apps/customer_app (gồm CustomerAuthScreen, CustomerHomeScreen, ReservationBookingScreen, MyReservationsScreen, TableQrScannerScreen, ActiveSessionScreen tích hợp đồng hồ đếm ngược + rung + gia hạn + trả bàn sớm + gọi món, và PointsAndHistoryScreen).
> Lưu ý: Chỉ sửa trong packages/core/lib/(theme|widgets) và apps/customer_app/. Mọi logic Firestore phải gọi qua các Service trong packages/core.`

---

#### 3. Prompt dành cho TRUNG (Sau khi pull Base của Trường về)
> `@PROJECT_SPEC.md Tôi là Trung. Hãy đọc kỹ tài liệu thiết kế. Gói packages/core đã có sẵn. Hãy thực hiện PHẦN C trong Mục 6: Code hoàn chỉnh ứng dụng apps/waiter_app (gồm WaiterAuthScreen, FloorMapScreen hiển thị sơ đồ bàn đổi màu realtime mỗi giây kèm đồng hồ và báo rung đa bàn, TableActionSheet đầy đủ các thao tác Mở bàn vãng lai / Check-in hộ / Gia hạn / Chuyển bàn / Yêu cầu nhả bàn / Đã dọn xong, QuickOrderScreen và WaiterTaskHubScreen 3 tab).
> Lưu ý: Tuyệt đối chỉ tạo và sửa file bên trong thư mục apps/waiter_app/, không sửa bất kỳ file nào ngoài thư mục này để tránh conflict Git.`
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
```
