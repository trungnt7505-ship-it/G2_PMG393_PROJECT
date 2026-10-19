import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Form cấu hình dùng chung: giữ bản nháp khi stream cập nhật và phát hiện lưu đè.
class AppConfigForm extends ConsumerStatefulWidget {
  final AppConfig config;
  const AppConfigForm({super.key, required this.config});

  @override
  ConsumerState<AppConfigForm> createState() => _AppConfigFormState();
}

class _AppConfigFormState extends ConsumerState<AppConfigForm> {
  static const labels = {
    'sessionMinutes': 'Thời lượng phiên (phút)',
    'extendStepMinutes': 'Mỗi lần gia hạn (phút)',
    'warnMinutes': 'Mốc cảnh báo (phút, cách nhau bằng dấu phẩy)',
    'reservationHoldMinutes': 'Giữ chỗ sau giờ hẹn (phút)',
    'bufferMinutes': 'Thời gian dọn bàn (phút)',
    'checkInEarlyMinutes': 'Cho phép đến sớm (phút)',
    'minAdvanceMinutes': 'Đặt trước tối thiểu (phút)',
    'maxAdvanceDays': 'Đặt trước tối đa (ngày)',
    'pointEarnVnd': 'Số VND để tích 1 điểm',
    'pointRedeemVnd': 'Giá trị 1 điểm khi đổi (VND)',
    'maxRedeemPercent': 'Giảm giá tối đa bằng điểm (%)',
    'earlyReleaseMinMinutes': 'Thời gian còn lại tối thiểu để trả sớm (phút)',
    'earlyReleaseBonusPoints': 'Điểm thưởng trả bàn sớm',
    'preOrderBonusPoints': 'Điểm thưởng đặt món trước',
  };
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late AppConfig _baseline;
  bool _dirty = false;
  bool _saving = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) {
      _controllers[key] = TextEditingController();
    }
    _load(widget.config);
  }

  void _load(AppConfig config) {
    _baseline = config;
    for (final entry in config.toMap().entries) {
      _controllers[entry.key]!.text = entry.value is List
          ? (entry.value as List).join(', ')
          : entry.value.toString();
    }
    _dirty = false;
  }

  @override
  void didUpdateWidget(covariant AppConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty &&
        !_saving &&
        oldWidget.config.toMap().toString() !=
            widget.config.toMap().toString()) {
      _load(widget.config);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (ref.read(currentUserProvider).valueOrNull?.userRole != UserRole.manager) {
      return;
    }
    try {
      final data = <String, dynamic>{};
      for (final entry in _controllers.entries) {
        data[entry.key] = entry.key == 'warnMinutes'
            ? entry.value.text
                .split(',')
                .map((v) => int.parse(v.trim()))
                .toList()
            : int.parse(entry.value.text.trim());
      }
      final config = AppConfig.fromMap(data);
      config.validate();
      setState(() {
        _saving = true;
        _message = null;
      });
      await ref.read(configServiceProvider).save(config, expected: _baseline);
      if (!mounted) return;
      setState(() {
        _baseline = config;
        _dirty = false;
        _saving = false;
        _error = false;
        _message = 'Đã lưu cấu hình hệ thống.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = true;
        _message = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = ref.watch(currentUserProvider).valueOrNull?.userRole ==
        UserRole.manager;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Cấu hình vận hành',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        'Cấu hình được dùng chung cho quầy, khách hàng và phục vụ. Thời lượng mới áp dụng khi tạo hoặc gia hạn phiên; thanh toán dùng cấu hình tại lúc chốt.')),
                for (final entry in labels.entries)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        key: Key('config_${entry.key}'),
                        controller: _controllers[entry.key],
                        enabled: isManager && !_saving,
                        decoration: InputDecoration(
                            labelText: entry.value,
                            border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() => _dirty = true),
                        validator: (value) {
                          final parts = entry.key == 'warnMinutes'
                              ? (value ?? '').split(',')
                              : [value ?? ''];
                          if (parts
                              .any((part) => int.tryParse(part.trim()) == null)) {
                            return 'Nhập số nguyên hợp lệ.';
                          }
                          return null;
                        },
                      )),
                if (_message != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_message!,
                          style: TextStyle(
                              color: _error ? Colors.red : Colors.green))),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  ElevatedButton.icon(
                      key: const Key('save_config'),
                      onPressed: isManager && _dirty && !_saving ? _save : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator())
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu cấu hình')),
                  OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _load(widget.config);
                                _message = null;
                                _formKey.currentState?.reset();
                              }),
                      child: const Text('Tải lại / Bỏ thay đổi')),
                ]),
              ],
            )),
      )),
    );
  }
}
