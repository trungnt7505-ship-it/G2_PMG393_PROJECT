import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import '../../repositories/customer_repository.dart';
import '../session/active_session_screen.dart';

/// Màn hình Check-in nhận bàn bằng mã QR bàn: `cafe://table/{tableId}?k={qrSecret}`.
///
/// Tính năng:
/// 1. Nhập hoặc dán nội dung mã QR trực tiếp từ clipboard.
/// 2. Hỗ trợ các nút mẫu test nhanh (Demo 1-chạm) phục vụ chấm điểm và kiểm thử nhanh.
/// 3. Xác thực QR bàn và mã bí mật secret thông qua [SessionService.checkInByTableQr].
/// 4. Chuyển ngay sang [ActiveSessionScreen] khi check-in thành công.
class TableQrScannerScreen extends ConsumerStatefulWidget {
  const TableQrScannerScreen({super.key});

  @override
  ConsumerState<TableQrScannerScreen> createState() =>
      _TableQrScannerScreenState();
}

class _TableQrScannerScreenState extends ConsumerState<TableQrScannerScreen> {
  final _qrController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _qrController.text = data.text!.trim();
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitCheckIn(String payload) async {
    final content = payload.trim();
    if (content.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập hoặc dán nội dung mã QR bàn.');
      return;
    }

    final uid = ref.read(authServiceProvider).currentUid;
    if (uid == null) {
      setState(() => _errorMessage = 'Vui lòng đăng nhập lại để thực hiện check-in.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionId = await ref.read(customerRepositoryProvider).checkInByTableQr(
            qrContent: content,
            customerId: uid,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in tại bàn'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Khung mô phỏng quét QR Scanner
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFFCC80), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white70, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Hướng camera về phía mã QR bàn\nhoặc dán nội dung mã bên dưới',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Ô nhập nội dung QR
            const Text(
              'Nội dung mã QR bàn',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF3E2723)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _qrController,
              decoration: InputDecoration(
                hintText: 'cafe://table/table_01?k=secret_01',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste, color: Color(0xFF5D4037)),
                  tooltip: 'Dán từ clipboard',
                  onPressed: _pasteFromClipboard,
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: _isLoading ? null : () => _submitCheckIn(_qrController.text),
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Xác thực & Check-in nhận bàn'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5D4037),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 28),

            // Khối phím bấm thử nghiệm nhanh (Demo Fast-Testing cho PRM393)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECE5DE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: Color(0xFFF57C00), size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Phím thử nhanh (Demo Check-in)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E2723)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bấm 1 chạm vào các bàn bên dưới để tự điền nội dung QR mẫu:',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickTableChip('Bàn 01', 'cafe://table/table_01?k=secret_01'),
                      _buildQuickTableChip('Bàn 02', 'cafe://table/table_02?k=secret_02'),
                      _buildQuickTableChip('Bàn 03', 'cafe://table/table_03?k=secret_03'),
                      _buildQuickTableChip('Bàn 04', 'cafe://table/table_04?k=secret_04'),
                      _buildQuickTableChip('Bàn 05', 'cafe://table/table_05?k=secret_05'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTableChip(String label, String payload) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: const Icon(Icons.table_bar, size: 16, color: Color(0xFF5D4037)),
      backgroundColor: Colors.white,
      onPressed: () {
        setState(() {
          _qrController.text = payload;
          _errorMessage = null;
        });
      },
    );
  }
}
