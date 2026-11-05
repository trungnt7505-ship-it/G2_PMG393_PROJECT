import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TableQrDialog extends StatelessWidget {
  const TableQrDialog({super.key, required this.table});

  final TableModel table;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('QR nhận bàn • ${table.name}'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${table.zone} • ${table.capacity} chỗ'),
              const SizedBox(height: 16),
              SizedBox.square(
                dimension: 240,
                child: QrImageView(
                  data: table.qrUrl,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mở Customer → Check-in bàn và quét mã này. '
                'Khách cần có lịch đặt đúng bàn trong giờ nhận bàn.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SelectableText(table.qrUrl),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: table.qrUrl));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép mã nhận bàn')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Sao chép mã'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
