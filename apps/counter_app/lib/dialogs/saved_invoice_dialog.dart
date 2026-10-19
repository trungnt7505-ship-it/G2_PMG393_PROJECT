import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'invoice_preview_dialog.dart';

/// Tải lại hóa đơn đã chốt; lỗi tải biên lai không thực hiện thu tiền lần nữa.
class SavedInvoiceDialog extends ConsumerStatefulWidget {
  final PaymentModel payment;
  const SavedInvoiceDialog({super.key, required this.payment});
  @override
  ConsumerState<SavedInvoiceDialog> createState() => _SavedInvoiceDialogState();
}

class _SavedInvoiceDialogState extends ConsumerState<SavedInvoiceDialog> {
  late Future<List<OrderItemModel>> _items;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items =
        ref.read(paymentServiceProvider).getPaymentItems(widget.payment.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<OrderItemModel>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return InvoicePreviewDialog(
              payment: widget.payment, items: snapshot.data!);
        }
        return AlertDialog(
            title: const Text('Hóa đơn đã được thanh toán'),
            content: snapshot.hasError
                ? Text(
                    'Không tải được chi tiết hóa đơn ${widget.payment.id}: ${snapshot.error}')
                : const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator())),
            actions: [
              if (snapshot.hasError)
                TextButton(
                    onPressed: () => setState(_load),
                    child: const Text('Thử lại')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng')),
            ]);
      });
}
