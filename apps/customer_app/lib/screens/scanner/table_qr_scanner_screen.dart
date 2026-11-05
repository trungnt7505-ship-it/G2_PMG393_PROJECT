import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../repositories/customer_repository.dart';
import '../session/active_session_screen.dart';

class TableQrScannerScreen extends ConsumerStatefulWidget {
  const TableQrScannerScreen({super.key});

  @override
  ConsumerState<TableQrScannerScreen> createState() =>
      _TableQrScannerScreenState();
}

class _TableQrScannerScreenState extends ConsumerState<TableQrScannerScreen> {
  final _qrController = TextEditingController();
  String? _lastScanned;

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitCheckIn(String qrContent, {String? reservationId}) async {
    if (_isLoading) return;
    final uid = ref.read(authServiceProvider).currentUid;
    if (uid == null) {
      setState(() =>
          _errorMessage = 'Vui lòng đăng nhập lại để thực hiện check-in.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionId =
          await ref.read(customerRepositoryProvider).checkInByTableQr(
                qrContent: qrContent,
                customerId: uid,
                reservationId: reservationId,
              );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in nhận bàn thành công! Chào mừng quý khách.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ActiveSessionScreen(sessionId: sessionId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyCheckInError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyCheckInError(Object error) {
    final msg = error.toString();
    if (msg.contains('permission-denied')) {
      return 'Tài khoản khách hiện chưa có quyền tự mở bàn. Vui lòng đưa mã đặt trước cho thu ngân để nhận bàn tại quầy.';
    }
    if (msg.contains('Bàn hiện đang có người sử dụng')) {
      return 'Bàn này hiện đang có người sử dụng. Vui lòng chọn bàn khác hoặc liên hệ nhân viên.';
    }
    if (msg.contains('needs_cleaning')) {
      return 'Bàn này đang cần dọn dẹp. Vui lòng nhờ phục vụ hỗ trợ dọn bàn trước nhé.';
    }
    if (msg.contains('Mã QR không đúng định dạng')) {
      return 'Mã QR không hợp lệ. Định dạng chuẩn: cafe://table/{tableId}?k={qrSecret}';
    }
    if (msg.contains('Mã bí mật không khớp')) {
      return 'Mã bí mật của bàn không chính xác hoặc đã được cấp mới.';
    }
    return msg.replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authServiceProvider).currentUid;
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in tại bàn')),
      body: uid == null
          ? const Center(child: Text('Vui lòng đăng nhập để nhận bàn.'))
          : ref.watch(customerReservationsProvider(uid)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Không tải được lịch đặt bàn.')),
                data: (reservations) => ref.watch(allTablesProvider).when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Center(
                          child: Text('Không tải được thông tin bàn.')),
                      data: (tables) {
                        final byId = {
                          for (final table in tables) table.id: table
                        };
                        final bookings = reservations
                            .where((r) => r.status == 'confirmed')
                            .toList()
                          ..sort((a, b) => a.startTime.compareTo(b.startTime));
                        return ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            SizedBox(
                              height: 220,
                              child: MobileScanner(
                                onDetect: (capture) {
                                  if (_isLoading || !mounted) return;
                                  for (final barcode in capture.barcodes) {
                                    final value = barcode.rawValue;
                                    if (value != null &&
                                        value != _lastScanned &&
                                        value.startsWith('cafe://table/')) {
                                      _lastScanned = value;
                                      _qrController.text = value;
                                      _submitCheckIn(value);
                                      break;
                                    }
                                  }
                                },
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text(
                                      'Không mở được camera. Bạn có thể dùng cách nhận bàn bên dưới.'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Hướng camera vào mã QR của bàn.'),
                            TextField(
                              controller: _qrController,
                              decoration: const InputDecoration(
                                  labelText: 'Hoặc nhập/dán mã QR bàn'),
                            ),
                            FilledButton(
                              onPressed: _isLoading
                                  ? null
                                  : () =>
                                      _submitCheckIn(_qrController.text.trim()),
                              child: const Text('Xác thực mã bàn'),
                            ),
                            const SizedBox(height: 20),
                            Text('Nhận bàn nhanh khi không quét được',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            if (_errorMessage != null)
                              Text(_errorMessage!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            if (_isLoading) const LinearProgressIndicator(),
                            if (bookings.isEmpty)
                              const Text(
                                  'Bạn chưa có lịch đặt bàn đã xác nhận.'),
                            for (final booking in bookings)
                              Card(
                                child: ListTile(
                                  title: Text(booking.tableName),
                                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm')
                                      .format(booking.startTime.toLocal())),
                                  trailing: FilledButton(
                                    onPressed: _isLoading ||
                                            byId[booking.tableId]
                                                    ?.qrSecret
                                                    .isNotEmpty !=
                                                true
                                        ? null
                                        : () => _submitCheckIn(
                                            byId[booking.tableId]!.qrUrl,
                                            reservationId: booking.id),
                                    child: const Text('Nhận bàn'),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              ),
    );
  }
}
