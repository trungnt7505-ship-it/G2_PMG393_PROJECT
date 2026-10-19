import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';
import 'saved_invoice_dialog.dart';
import 'universal_qr_scanner_dialog.dart';

/// Modal thanh toán và đóng phiên bàn dành cho Quầy POS.
/// Tự động giới hạn số điểm đổi không vượt quá 50% tổng tiền tạm tính.
class PaymentCheckoutModal extends ConsumerStatefulWidget {
  final SessionModel session;
  final List<OrderItemModel> items;
  final UserModel? initialMember;
  final String? takeawayOrderId;

  const PaymentCheckoutModal({
    super.key,
    required this.session,
    this.items = const [],
    this.initialMember,
    this.takeawayOrderId,
  });

  @override
  ConsumerState<PaymentCheckoutModal> createState() =>
      _PaymentCheckoutModalState();
}

class _PaymentCheckoutModalState extends ConsumerState<PaymentCheckoutModal> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pointsController =
      TextEditingController(text: '0');

  UserModel? _member;
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  bool _isSearchingMember = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _memberLookupVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialMember != null) {
      _member = widget.initialMember;
    } else if (widget.session.customerId != null &&
        widget.session.customerId!.isNotEmpty) {
      _loadCustomerById(widget.session.customerId!);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerById(String uid) async {
    final version = ++_memberLookupVersion;
    setState(() {
      _isSearchingMember = true;
      _errorMessage = null;
      _member = null;
      _pointsController.text = '0';
    });
    try {
      final customer =
          await ref.read(authServiceProvider).findCustomerById(uid);
      if (!mounted || version != _memberLookupVersion) return;
      setState(() {
        _member = customer;
        _isSearchingMember = false;
        if (customer == null) {
          _errorMessage = 'Không tìm thấy thành viên hợp lệ với mã QR này.';
        }
      });
    } catch (e) {
      if (!mounted || version != _memberLookupVersion) return;
      setState(() {
        _isSearchingMember = false;
        _errorMessage = 'Lỗi tra cứu thành viên: $e';
      });
    }
  }

  Future<void> _searchMemberByPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    final version = ++_memberLookupVersion;

    setState(() {
      _isSearchingMember = true;
      _errorMessage = null;
      _member = null;
      _pointsController.text = '0';
    });

    try {
      final authService = ref.read(authServiceProvider);
      final customer = await authService.findCustomerByPhone(phone);
      if (!mounted || version != _memberLookupVersion) return;
      setState(() {
        _isSearchingMember = false;
        if (customer != null && customer.userRole == UserRole.customer) {
          _member = customer;
        } else {
          _errorMessage = 'Không tìm thấy khách hàng với số điện thoại $phone.';
        }
      });
    } catch (e) {
      if (!mounted || version != _memberLookupVersion) return;
      setState(() {
        _isSearchingMember = false;
        _errorMessage = 'Lỗi tìm kiếm: $e';
      });
    }
  }

  void _onPointsChanged(String value, int maxPointsAllowed) {
    final parsed = int.tryParse(value) ?? 0;
    if (parsed > maxPointsAllowed) {
      // Tự động chặn và điều chỉnh về mức trần cho phép (tối đa 50% tiền hoặc số điểm hiện có)
      _pointsController.text = maxPointsAllowed.toString();
      _pointsController.selection = TextSelection.fromPosition(
        TextPosition(offset: _pointsController.text.length),
      );
    }
    setState(() {});
  }

  Future<void> _submitPayment(
      PaymentCalculationResult calc, AppConfig config) async {
    if (_isSubmitting || _isSearchingMember) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) throw StateError('Vui lòng đăng nhập lại.');
      final cashierId = currentUser.id;

      final payment = widget.takeawayOrderId != null
          ? await paymentService.payTakeaway(
              orderId: widget.takeawayOrderId!,
              cashierId: cashierId,
              method: _selectedMethod,
              customerId: _member?.id ?? '',
              pointsUsed: calc.pointsUsed,
              expectedSubtotal: calc.subtotal,
              expectedConfig: config)
          : await paymentService.payAndClose(
              sessionId: widget.session.id,
              cashierId: cashierId,
              method: _selectedMethod,
              customerId: _member?.id,
              pointsUsed: calc.pointsUsed,
              expectedSubtotal: calc.subtotal,
              expectedConfig: config,
            );

      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();

      // Mở hộp thoại xem hóa đơn
      showDialog(
        context: navigator.context,
        builder: (ctx) => SavedInvoiceDialog(payment: payment),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'vi_VN');
    final configAsync = ref.watch(appConfigProvider);
    final config = configAsync.valueOrNull ?? AppConfig.defaultConfig;
    final sessionAsync = widget.takeawayOrderId == null
        ? ref.watch(sessionStreamProvider(widget.session.id))
        : null;
    final session = sessionAsync?.valueOrNull ?? widget.session;
    final sessionClosed = sessionAsync != null &&
        !sessionAsync.isLoading &&
        (sessionAsync.valueOrNull == null ||
            !['active', 'billing'].contains(session.status));
    final reservationId = session.reservationId;
    final reservationAsync = reservationId != null && reservationId.isNotEmpty
        ? ref.watch(reservationByIdProvider(reservationId))
        : null;
    final hasPreOrder = reservationAsync?.valueOrNull?.hasPreOrder ?? false;
    final calculationLoading = configAsync.isLoading ||
        (reservationAsync?.isLoading ?? false) ||
        (sessionAsync?.isLoading ?? false);
    final calculationError =
        configAsync.error ?? reservationAsync?.error ?? sessionAsync?.error;
    final subtotal = session.subtotal;

    // Giới hạn điểm tối đa: không quá 50% subtotal và không quá điểm member đang có
    final maxPointsByBill = (subtotal * config.maxRedeemPercent) ~/
        (100 * max(1, config.pointRedeemVnd));
    final memberPoints = _member?.points ?? 0;
    final maxPointsAllowed =
        _member != null ? min(maxPointsByBill, memberPoints) : 0;

    final enteredPoints = int.tryParse(_pointsController.text) ?? 0;
    final validPointsToUse = enteredPoints.clamp(0, maxPointsAllowed);

    // Tính toán tiền thực tế
    PaymentCalculationResult calc;
    try {
      calc = PaymentService.calculatePayment(
        subtotal: subtotal,
        pointsUsed: validPointsToUse,
        earlyReleased: session.earlyReleased,
        hasPreOrder: hasPreOrder,
        config: config,
      );
    } catch (e) {
      return AlertDialog(
          title: const Text('Cấu hình thanh toán không hợp lệ'),
          content: Text('$e'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'))
          ]);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Row(
                    children: [
                      const Icon(Icons.point_of_sale,
                          color: AppColors.primary, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                        'Thanh toán - ${widget.session.tableName}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      )),
                    ],
                  )),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // 1. Phần Thành viên & Tích điểm
              const Text(
                '1. Thông tin Khách hàng / Thành viên',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (_member != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _member!.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                                'SĐT: ${_member!.phone} • Điểm hiện có: ${_member!.points} điểm'),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _member = null;
                            _pointsController.text = '0';
                          });
                        },
                        child: const Text('Bỏ chọn'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Nhập số điện thoại tìm thành viên',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        onSubmitted: (_) => _searchMemberByPhone(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed:
                          _isSearchingMember ? null : _searchMemberByPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSearchingMember
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Tìm'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Quét QR Thành viên',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => UniversalQrScannerDialog(
                            onMemberScanned: (uid) => _loadCustomerById(uid),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // 2. Đổi điểm giảm giá
              if (_member != null &&
                  _member!.points > 0 &&
                  maxPointsAllowed > 0) ...[
                Text(
                  '2. Đổi điểm giảm giá (Tối đa ${config.maxRedeemPercent}% hóa đơn)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('points_input_field'),
                        controller: _pointsController,
                        decoration: InputDecoration(
                          labelText:
                              'Số điểm muốn đổi (1 điểm = ${currencyFmt.format(config.pointRedeemVnd)}đ)',
                          helperText:
                              'Tối đa được đổi: $maxPointsAllowed điểm (${currencyFmt.format(maxPointsAllowed * config.pointRedeemVnd)} đ)',
                          helperMaxLines: 2,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) =>
                            _onPointsChanged(val, maxPointsAllowed),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        _pointsController.text = maxPointsAllowed.toString();
                        setState(() {});
                      },
                      child: const Text('Dùng tối đa'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 3. Phương thức thanh toán
              const Text(
                '3. Phương thức thanh toán',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: PaymentMethod.cash,
                    label: Text('Tiền mặt'),
                    icon: Icon(Icons.money),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.qr,
                    label: Text('Chuyển khoản QR'),
                    icon: Icon(Icons.qr_code),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.card,
                    label: Text('Thẻ ngân hàng'),
                    icon: Icon(Icons.credit_card),
                  ),
                ],
                selected: {_selectedMethod},
                onSelectionChanged: (set) {
                  setState(() => _selectedMethod = set.first);
                },
              ),
              const SizedBox(height: 16),

              // 4. Chi tiết bảng tính tiền & Điểm thưởng
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính đơn hàng:'),
                        Text(
                          '${currencyFmt.format(calc.subtotal)} đ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (calc.discount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Giảm trừ điểm (${calc.pointsUsed} điểm):'),
                          Text(
                            '-${currencyFmt.format(calc.discount)} đ',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SỐ TIỀN THỰC THU:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${currencyFmt.format(calc.total)} đ',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(
                                'Tích lũy (${currencyFmt.format(config.pointEarnVnd)}đ = 1 điểm):')),
                        Text(
                            '+${_member == null ? 0 : calc.pointsEarned} điểm'),
                      ],
                    ),
                    if (_member != null && calc.bonusEarlyRelease > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Thưởng trả bàn sớm (>=${config.earlyReleaseMinMinutes}p):'),
                          Text(
                            '+${calc.bonusEarlyRelease} điểm',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                    if (_member != null && calc.bonusPreOrder > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Thưởng đặt món trước:'),
                          Text(
                            '+${calc.bonusPreOrder} điểm',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (calculationLoading) const LinearProgressIndicator(),
              if (calculationError != null)
                Text('Không tải được cấu hình/đặt chỗ: $calculationError'),
              if (sessionClosed)
                const Text(
                    'Phiên bàn đã đóng hoặc không còn tồn tại. Vui lòng đóng hộp thanh toán.'),
              const Text(
                  'Tiền mặt, QR và thẻ là phương thức ghi nhận thu tiền; hãy xác nhận đã nhận tiền trước khi chốt.'),

              // Nút hoàn tất thanh toán
              ElevatedButton.icon(
                key: const Key('confirm_payment_button'),
                onPressed: _isSubmitting ||
                        _isSearchingMember ||
                        calculationLoading ||
                        calculationError != null ||
                        sessionClosed
                    ? null
                    : () => _submitPayment(calc, config),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _isSubmitting
                      ? 'Đang xử lý...'
                      : widget.takeawayOrderId == null
                          ? 'Xác nhận Thanh toán & Đóng bàn'
                          : 'Xác nhận đã thu tiền mang đi',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
