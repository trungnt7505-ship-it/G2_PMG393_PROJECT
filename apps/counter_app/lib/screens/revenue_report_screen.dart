import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../dialogs/saved_invoice_dialog.dart';
import '../models/revenue_period.dart';

final revenuePaymentsProvider = StreamProvider.autoDispose
    .family<List<PaymentModel>, ({DateTime start, DateTime end})>((ref, range) {
  return ref
      .watch(paymentServiceProvider)
      .watchPaymentsBetween(range.start, range.end);
});

class RevenueReportScreen extends ConsumerStatefulWidget {
  const RevenueReportScreen({super.key});

  @override
  ConsumerState<RevenueReportScreen> createState() =>
      _RevenueReportScreenState();
}

class _RevenueReportScreenState extends ConsumerState<RevenueReportScreen> {
  RevenuePeriod _period = RevenuePeriod.day;
  late DateTime _date;
  final _money = NumberFormat('#,###', 'vi_VN');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final now =
        ClockService.instance.serverNow.toUtc().add(const Duration(hours: 7));
    _date = DateTime(now.year, now.month, now.day);
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày trong kỳ muốn xem',
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) {
    final range = _period.range(_date);
    final payments = ref.watch(revenuePaymentsProvider(range));
    final start = range.start.add(const Duration(hours: 7));
    final lastDay = range.end
        .add(const Duration(hours: 7))
        .subtract(const Duration(days: 1));
    return Scaffold(
      appBar: AppBar(title: const Text('Doanh thu')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final period in RevenuePeriod.values)
                  ChoiceChip(
                      label: Text(period.label),
                      selected: _period == period,
                      onSelected: (_) => setState(() => _period = period)),
                OutlinedButton.icon(
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_dateFormat.format(_date))),
              ]),
              const SizedBox(height: 12),
              Text(
                  '${_dateFormat.format(start)} – ${_dateFormat.format(lastDay)}',
                  style: Theme.of(context).textTheme.titleMedium),
              const Text(
                  'Theo thời điểm thanh toán, giờ Việt Nam. Tuần bắt đầu từ thứ Hai.'),
              const SizedBox(height: 16),
              payments.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Column(children: [
                  const Text(
                      'Không tải được doanh thu. Kiểm tra kết nối và thử lại.'),
                  TextButton(
                      onPressed: () =>
                          ref.invalidate(revenuePaymentsProvider(range)),
                      child: const Text('Thử lại')),
                ]),
                data: (items) {
                  final total = items.fold<int>(0, (sum, p) => sum + p.total);
                  final discount =
                      items.fold<int>(0, (sum, p) => sum + p.discount);
                  final days = <String, int>{};
                  for (final payment in items) {
                    final date =
                        payment.paidAt.toUtc().add(const Duration(hours: 7));
                    final key = DateFormat('yyyy-MM-dd').format(date);
                    days.update(key, (value) => value + payment.total,
                        ifAbsent: () => payment.total);
                  }
                  final keys = days.keys.toList()..sort();
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Tổng doanh thu thực thu'),
                                      Text('${_money.format(total)} đ',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium),
                                      Text(
                                          '${items.length} hóa đơn • Đã giảm ${_money.format(discount)} đ bằng điểm'),
                                      const Text(
                                          'Bao gồm hóa đơn tại bàn và mang đi đã thanh toán.'),
                                    ]))),
                        if (items.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  'Chưa có hóa đơn thanh toán trong kỳ này.')),
                        if (_period != RevenuePeriod.day &&
                            items.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Doanh thu từng ngày',
                              style: Theme.of(context).textTheme.titleMedium),
                          for (final day in keys)
                            ListTile(
                                title: Text(
                                    _dateFormat.format(DateTime.parse(day))),
                                trailing:
                                    Text('${_money.format(days[day])} đ')),
                        ],
                        const SizedBox(height: 16),
                        Text('Hóa đơn trong kỳ',
                            style: Theme.of(context).textTheme.titleMedium),
                        for (final payment in items)
                          ListTile(
                              title: Text(
                                  '${payment.tableName} • ${_money.format(payment.total)} đ'),
                              subtitle: Text(
                                  '${DateFormat('dd/MM/yyyy HH:mm').format(payment.paidAt.toUtc().add(const Duration(hours: 7)))} • ${payment.id}'),
                              trailing: const Icon(Icons.receipt_long),
                              onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      SavedInvoiceDialog(payment: payment))),
                      ]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
