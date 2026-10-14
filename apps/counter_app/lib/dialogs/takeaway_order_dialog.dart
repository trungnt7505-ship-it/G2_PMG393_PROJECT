import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';

/// Hộp thoại tạo đơn mang đi (Takeaway) siêu tốc tại quầy POS.
class TakeawayOrderDialog extends ConsumerStatefulWidget {
  const TakeawayOrderDialog({super.key});

  @override
  ConsumerState<TakeawayOrderDialog> createState() =>
      _TakeawayOrderDialogState();
}

class _TakeawayOrderDialogState extends ConsumerState<TakeawayOrderDialog> {
  final Map<String, int> _selectedQuantities = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final currencyFmt = NumberFormat('#,###', 'vi_VN');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        height: 580,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.takeout_dining, color: AppColors.primary, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Tạo đơn mang đi (Takeaway)',
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
            const Divider(height: 20),

            // Danh sách món
            Expanded(
              child: menuItemsAsync.when(
                data: (items) {
                  final availableItems = items.where((i) => i.available).toList();
                  if (availableItems.isEmpty) {
                    return const Center(child: Text('Chưa có món nào sẵn sàng.'));
                  }
                  return ListView.separated(
                    itemCount: availableItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = availableItems[index];
                      final qty = _selectedQuantities[item.id] ?? 0;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.brown.shade100,
                          child: const Icon(Icons.local_cafe, color: AppColors.primary),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item.category} • ${currencyFmt.format(item.price)} đ',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (qty > 0) ...[
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  setState(() {
                                    if (qty > 1) {
                                      _selectedQuantities[item.id] = qty - 1;
                                    } else {
                                      _selectedQuantities.remove(item.id);
                                    }
                                  });
                                },
                              ),
                              Text(
                                '$qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: AppColors.primary),
                              onPressed: () {
                                setState(() {
                                  _selectedQuantities[item.id] = qty + 1;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
              ),
            ),
            const Divider(height: 20),

            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],

            // Chốt tạo đơn
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting || _selectedQuantities.isEmpty
                        ? null
                        : () => _submitTakeaway(menuItemsAsync.value ?? []),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Gửi đơn vào hàng đợi pha chế',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitTakeaway(List<MenuItemModel> allItems) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final orderItems = <OrderItemModel>[];
      for (final entry in _selectedQuantities.entries) {
        final item = allItems.firstWhere((i) => i.id == entry.key);
        orderItems.add(
          OrderItemModel(
            itemId: item.id,
            name: item.name,
            unitPrice: item.price,
            qty: entry.value,
            selectedOptions: const [],
          ),
        );
      }

      final orderService = ref.read(orderServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;

      await orderService.submitOrder(
        sessionId: 'takeaway_orders',
        tableId: 'takeaway',
        tableName: 'Mang đi (Takeaway)',
        items: orderItems,
        createdBy: currentUser?.displayName ?? 'Thu ngân',
        createdByRole: 'counter',
        type: OrderType.takeaway,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo đơn mang đi thành công và gửi sang hàng đợi!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }
}

