import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import '../../widgets/item_options_dialog.dart';

class TakeawayScreen extends ConsumerStatefulWidget {
  const TakeawayScreen({super.key});
  @override
  ConsumerState<TakeawayScreen> createState() => _TakeawayScreenState();
}

class _TakeawayScreenState extends ConsumerState<TakeawayScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final cart = <OrderItemModel>[];
  bool initialized = false, busy = false;
  DateTime? pickup;
  String? error, orderKey;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final uid = ref.read(authServiceProvider).currentUid;
    if (uid == null ||
        cart.isEmpty ||
        name.text.trim().isEmpty ||
        phone.text.trim().length < 8) {
      setState(() =>
          error = 'Vui lòng chọn món, nhập tên và số điện thoại người nhận.');
      return;
    }
    if (pickup != null && pickup!.isBefore(DateTime.now())) {
      setState(() => error = 'Giờ nhận đã qua. Hãy chọn lại.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    orderKey ??= '${uid}_${DateTime.now().microsecondsSinceEpoch}';
    try {
      await ref.read(orderServiceProvider).submitOrder(
          sessionId: 'takeaway_orders',
          tableId: 'takeaway',
          tableName:
              'Mang đi · ${name.text.trim()} · ${phone.text.trim()}${pickup == null ? ' · Sớm nhất' : ' · ${pickup!.hour}:${pickup!.minute.toString().padLeft(2, '0')}'}',
          items: List.of(cart),
          createdBy: uid,
          createdByRole: 'customer',
          type: OrderType.takeaway,
          recipientName: name.text.trim(),
          recipientPhone: phone.text.trim(),
          pickupAt: pickup,
          clientOrderId: orderKey);
      if (mounted)
        setState(() {
          cart.clear();
          orderKey = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (!initialized && user != null) {
      name.text = user.displayName;
      phone.text = user.phone;
      initialized = true;
    }
    final uid = ref.watch(authServiceProvider).currentUid ?? '';
    final menu = ref.watch(menuItemsProvider);
    final history = ref.watch(customerTakeawaysProvider(uid));
    return Scaffold(
        appBar: AppBar(title: const Text('Đặt món mang đi')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'Thanh toán tại quầy khi đến nhận. Có thể sửa người nhận cho riêng đơn này.'),
          TextField(
              controller: name,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Tên người nhận')),
          TextField(
              controller: phone,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại')),
          ListTile(
              title: Text(pickup == null
                  ? 'Nhận sớm nhất sau khi quán xác nhận'
                  : 'Nhận lúc ${pickup!.hour}:${pickup!.minute.toString().padLeft(2, '0')} hôm nay'),
              trailing: TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final t = await showTimePicker(
                              context: context, initialTime: TimeOfDay.now());
                          if (t != null && mounted)
                            setState(() {
                              final n = DateTime.now();
                              pickup = DateTime(
                                  n.year, n.month, n.day, t.hour, t.minute);
                            });
                        },
                  child: const Text('Hẹn giờ'))),
          if (pickup != null)
            TextButton(
                onPressed: busy ? null : () => setState(() => pickup = null),
                child: const Text('Chọn nhận sớm nhất')),
          menu.when(
              data: (items) => Column(
                  children: items
                      .where((i) => i.available)
                      .map((item) => ListTile(
                          title: Text(item.name),
                          subtitle: Text('${item.price} đ'),
                          trailing: IconButton(
                              icon: const Icon(Icons.add_circle),
                              onPressed: busy
                                  ? null
                                  : () => showDialog<void>(
                                      context: context,
                                      builder: (_) => ItemOptionsDialog(
                                          item: item,
                                          onConfirm: (value) => setState(() {
                                                cart.add(value);
                                                orderKey = null;
                                              }))))))
                      .toList()),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Không tải được menu: $e')),
          const Divider(),
          ...cart.asMap().entries.map((e) => ListTile(
              title: Text('${e.value.qty} × ${e.value.name}'),
              subtitle: Text('${e.value.totalPrice} đ'),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            cart.removeAt(e.key);
                            orderKey = null;
                          })))),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
              onPressed: busy || cart.isEmpty ? null : submit,
              child: Text(busy
                  ? 'Đang gửi...'
                  : 'Gửi đơn · ${cart.fold<int>(0, (sum, i) => sum + i.totalPrice)} đ')),
          const SizedBox(height: 24),
          const Text('Đơn mang đi của tôi', style: TextStyle(fontSize: 20)),
          history.when(
              data: (rows) => Column(
                      children: rows.map((r) {
                    const labels = {
                      'pending': 'Chờ xác nhận',
                      'confirmed': 'Đã xác nhận',
                      'preparing': 'Đang chuẩn bị',
                      'ready': 'Sẵn sàng nhận',
                      'served': 'Đã giao',
                      'cancelled': 'Đã hủy'
                    };
                    return Card(
                        child: ListTile(
                            title: Text(
                                '${labels[r['status']] ?? r['status']} · ${r['total']} đ'),
                            subtitle: Text(
                                '${r['tableName']}\n${r['paymentId'] == null ? 'Chưa thanh toán' : 'Đã thanh toán'}${r['cancelReason'] == null ? '' : '\n${r['cancelReason']}'}')));
                  }).toList()),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Không tải được đơn: $e')),
        ]));
  }
}
