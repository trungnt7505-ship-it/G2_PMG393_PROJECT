import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/customer_repository.dart';

class EditContactDialog extends ConsumerStatefulWidget {
  const EditContactDialog({super.key, required this.customer});
  final UserModel customer;

  @override
  ConsumerState<EditContactDialog> createState() => _EditContactDialogState();
}

class _EditContactDialogState extends ConsumerState<EditContactDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer.displayName);
    _phone = TextEditingController(text: widget.customer.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(customerRepositoryProvider).updateContactInfo(
          expectedUid: widget.customer.id,
          displayName: _name.text,
          phone: _phone.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = error is ArgumentError
              ? error.message.toString()
              : error is StateError
                  ? error.message.toString()
                  : 'Không lưu được thông tin. Vui lòng kiểm tra kết nối và thử lại.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Thông tin cá nhân'),
        content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Họ tên')),
                const SizedBox(height: 12),
                TextField(
                    controller: _phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Số điện thoại', hintText: '0912345678')),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ],
            ))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Đang lưu…' : 'Lưu thay đổi')),
        ],
      ),
    );
  }
}
