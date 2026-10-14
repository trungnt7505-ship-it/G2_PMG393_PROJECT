import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:core/core.dart';

/// Hộp thoại quét mã QR đa năng tại quầy POS:
/// - Quét QR đơn đặt trước (`cafe://preorder/{resId}`): Tự động mở bàn và duyệt đơn.
/// - Quét QR tại bàn (`cafe://table/{tableId}?k={qrSecret}`): Nhận diện bàn trên sơ đồ.
/// - Quét QR thẻ thành viên (`cafe://member/{uid}`): Trả về UID thành viên để tích/đổi điểm.
class UniversalQrScannerDialog extends ConsumerStatefulWidget {
  final Function(String memberUid)? onMemberScanned;
  final Function(String tableId)? onTableScanned;

  const UniversalQrScannerDialog({
    super.key,
    this.onMemberScanned,
    this.onTableScanned,
  });

  @override
  ConsumerState<UniversalQrScannerDialog> createState() =>
      _UniversalQrScannerDialogState();
}

class _UniversalQrScannerDialogState
    extends ConsumerState<UniversalQrScannerDialog> {
  final TextEditingController _manualInputController = TextEditingController();
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _handleQrCode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang xử lý mã: $code...';
      _isError = false;
    });

    try {
      final currentUser = ref.read(currentUserProvider).value;
      final counterUid = currentUser?.id ?? 'counter_pos';

      // 1. Quét QR đơn đặt trước (cafe://preorder/{resId})
      if (code.startsWith('cafe://preorder/')) {
        final sessionService = ref.read(sessionServiceProvider);
        final sessionId = await sessionService.checkInByPreOrderQrAtCounter(
          qrContent: code,
          counterUid: counterUid,
        );

        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Check-in đơn đặt trước thành công! Mã phiên: $sessionId';
          _isError = false;
        });

        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop(code);
        return;
      }

      // 2. Quét QR bàn (cafe://table/{tableId}?k={qrSecret})
      if (code.startsWith('cafe://table/')) {
        final uri = Uri.parse(code);
        final tableId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : uri.path;

        if (widget.onTableScanned != null) {
          widget.onTableScanned!(tableId);
        }

        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Đã nhận diện bàn: $tableId';
          _isError = false;
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop(tableId);
        return;
      }

      // 3. Quét QR thành viên (cafe://member/{uid})
      if (code.startsWith('cafe://member/')) {
        final memberUid = code.replaceFirst('cafe://member/', '');

        if (widget.onMemberScanned != null) {
          widget.onMemberScanned!(memberUid);
        }

        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Đã nhận diện thành viên: $memberUid';
          _isError = false;
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop(memberUid);
        return;
      }

      // Mã không khớp định dạng
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Định dạng mã QR không hợp lệ (cần cafe://preorder, cafe://table, cafe://member).';
        _isError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Thất bại: ${e.toString().replaceAll('Exception: ', '')}';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Quét mã QR tại Quầy',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Hỗ trợ: QR Đơn đặt trước (cafe://preorder/..), QR Bàn (cafe://table/..), hoặc QR Thành viên (cafe://member/..)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Khung Camera Scanner
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            _handleQrCode(barcode.rawValue!);
                            break;
                          }
                        }
                      },
                    ),
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.accent, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    if (_isProcessing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nhập thủ công dành cho máy Desktop / Test Emulator
            TextField(
              controller: _manualInputController,
              decoration: InputDecoration(
                labelText: 'Hoặc nhập mã test thủ công',
                hintText: 'VD: cafe://preorder/res_123 hoặc cafe://member/uid_abc',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _handleQrCode(_manualInputController.text),
                ),
              ),
              onSubmitted: _handleQrCode,
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isError
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError ? Colors.red : Colors.green,
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isError ? Colors.red.shade900 : Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

