import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:core/core.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Hộp thoại hiển thị mã QR thành viên để quét tại Quầy POS khi thanh toán tích/đổi điểm.
///
/// Mã định danh chỉ mang UID: `cafe://member/{uid}`.
/// Quầy xác minh thông tin qua `AuthService.findCustomerById` chứ không tin tưởng dữ liệu client tự nhận.
class MemberQrDialog extends StatelessWidget {
  final UserModel user;

  const MemberQrDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final qrData = 'cafe://member/${user.id}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code, color: Color(0xFF5D4037)),
                    SizedBox(width: 8),
                    Text(
                      'Mã Thành Viên',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF3E2723),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF4E342E),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName.isNotEmpty ? user.displayName : 'Khách hàng',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${user.points} điểm tích lũy',
              style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'UID: ${user.id}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép mã UID thành viên!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy, size: 16, color: Color(0xFF5D4037)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đưa mã này cho nhân viên quầy thu ngân khi thanh toán để tích hoặc đổi điểm.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
