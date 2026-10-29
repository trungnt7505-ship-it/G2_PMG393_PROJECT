import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../viewmodels/reservation_booking_viewmodel.dart';
import '../../widgets/item_options_dialog.dart';
import 'my_reservations_screen.dart';

/// Màn hình Đặt bàn trước (ReservationBookingScreen) - MVVM Pattern.
///
/// Tính năng:
/// 1. Chọn thời gian bắt đầu và số lượng khách theo giới hạn cấu hình `AppConfig`.
/// 2. Tìm kiếm bàn khả dụng thông qua [ReservationService.getAvailableTables] (chống trùng 5 slot).
/// 3. Chọn các món đặt trước (Pre-order items) kèm tùy chọn (options) và ghi chú để nhận điểm thưởng `preOrderBonusPoints`.
/// 4. Tạo đơn đặt và hiển thị mã QR `cafe://preorder/{resId}` trực quan.
class ReservationBookingScreen extends ConsumerStatefulWidget {
  const ReservationBookingScreen({super.key});

  @override
  ConsumerState<ReservationBookingScreen> createState() =>
      _ReservationBookingScreenState();
}

class _ReservationBookingScreenState
    extends ConsumerState<ReservationBookingScreen> {
  final _formatter = NumberFormat('#,###', 'vi_VN');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationBookingViewModelProvider);
    final vm = ref.read(reservationBookingViewModelProvider.notifier);
    final config = ref.watch(appConfigProvider).value ?? AppConfig.defaultConfig;
    final user = ref.watch(currentUserProvider).value;
    final menuAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt bàn trước'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bước 1: Chọn thời gian và số khách
          _buildStepHeader(1, 'Thời gian & Số lượng khách'),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: Color(0xFF5D4037)),
                    title: const Text('Thời gian bắt đầu'),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy · HH:mm').format(state.startTime),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () => _pickDateTime(context, config, state.startTime, vm),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.people_outline, color: Color(0xFF5D4037)),
                          SizedBox(width: 12),
                          Text('Số lượng khách', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                      DropdownButton<int>(
                        value: state.partySize,
                        underline: const SizedBox(),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1} khách', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) vm.setPartySize(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: state.isSearchingTables ? null : vm.findAvailableTables,
                    icon: state.isSearchingTables
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Kiểm tra bàn trống'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Bước 2: Chọn bàn
          _buildStepHeader(2, 'Chọn bàn phù hợp'),
          const SizedBox(height: 10),
          if (state.availableTables.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Các bàn còn trống trong khung giờ:'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.availableTables.map((table) {
                        final isSelected = state.selectedTable?.id == table.id;
                        return ChoiceChip(
                          label: Text('${table.name} (${table.capacity} chỗ)'),
                          selected: isSelected,
                          selectedColor: const Color(0xFFD7CCC8),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF3E2723) : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => vm.selectTable(table),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECE5DE)),
              ),
              child: Center(
                child: Text(
                  state.errorMessage ?? 'Vui lòng bấm "Kiểm tra bàn trống" để xem danh sách bàn khả dụng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: state.errorMessage != null ? Colors.red : Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Bước 3: Đặt món trước (Pre-order Items)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepHeader(3, 'Món đặt trước (Tùy chọn)'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${config.preOrderBonusPoints} điểm thưởng',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Đặt món trước giúp quán chuẩn bị sẵn sàng khi bạn tới và nhận thêm điểm thưởng tích lũy!',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 10),

          // Giỏ món đặt trước hiện tại
          if (state.preOrderItems.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ...state.preOrderItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final optionsDesc = item.selectedOptions
                          .map((o) => '${o.choiceName}${o.extraPrice > 0 ? " (+${_formatter.format(o.extraPrice)}đ)" : ""}')
                          .join(', ');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.qty}x',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (optionsDesc.isNotEmpty)
                                    Text(optionsDesc, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                  if (item.note != null && item.note!.isNotEmpty)
                                    Text('Ghi chú: ${item.note}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54)),
                                ],
                              ),
                            ),
                            Text(
                              '${_formatter.format(item.totalPrice)} đ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                              onPressed: () => vm.removePreOrderItem(idx),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính món đặt trước:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${_formatter.format(state.preOrderTotal)} đ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Nút chọn thêm món
          OutlinedButton.icon(
            onPressed: () => _showAddPreOrderDialog(context, menuAsync, vm),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Thêm món vào đặt trước'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5D4037),
              side: const BorderSide(color: Color(0xFFBCAAA4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 28),

          // Hiển thị thông báo lỗi nếu có
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Nút xác nhận đặt bàn
          FilledButton(
            onPressed: state.isSubmitting || state.selectedTable == null || user == null
                ? null
                : () async {
                    final resId = await vm.submitReservation(user: user, config: config);
                    if (!context.mounted) return;
                    if (resId != null) {
                      _showSuccessDialog(context, resId, state.selectedTable!.name, state.startTime);
                    } else if (state.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.errorMessage!),
                          backgroundColor: Colors.red.shade700,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: state.isSubmitting
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Xác nhận đặt bàn',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStepHeader(int step, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF5D4037),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3E2723)),
        ),
      ],
    );
  }

  Future<void> _pickDateTime(
    BuildContext context,
    AppConfig config,
    DateTime current,
    ReservationBookingViewModel vm,
  ) async {
    final now = DateTime.now();
    final firstDate = now;
    final lastDate = now.add(Duration(days: config.maxAdvanceDays));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current.isBefore(firstDate) ? firstDate : current,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (pickedTime != null) {
      final combined = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      vm.setStartTime(combined);
    }
  }

  void _showAddPreOrderDialog(
    BuildContext context,
    AsyncValue<List<MenuItemModel>> menuAsync,
    ReservationBookingViewModel vm,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Chọn món đặt trước',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Expanded(
              child: menuAsync.when(
                data: (items) {
                  final available = items.where((i) => i.available).toList();
                  if (available.isEmpty) {
                    return const Center(child: Text('Hiện không có món nào khả dụng.'));
                  }
                  return ListView.separated(
                    controller: scrollController,
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = available[idx];
                      return ListTile(
                        leading: const Icon(Icons.coffee, color: Color(0xFF5D4037)),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${_formatter.format(item.price)} đ · ${item.category}'),
                        trailing: const Icon(Icons.add_circle, color: Color(0xFF5D4037)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          showDialog<void>(
                            context: context,
                            builder: (_) => ItemOptionsDialog(
                              item: item,
                              onConfirm: (orderItem) {
                                vm.addPreOrderItem(orderItem);
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(
    BuildContext context,
    String resId,
    String tableName,
    DateTime startTime,
  ) {
    final qrPayload = 'cafe://preorder/$resId';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Đặt bàn thành công!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bàn: $tableName · ${DateFormat('dd/MM HH:mm').format(startTime)}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: SizedBox.square(
                dimension: 160,
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 160,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              qrPayload,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Sao chép mã QR đặt trước'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qrPayload));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép mã đặt bàn!')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Đóng'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5D4037)),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const MyReservationsScreen(),
                ),
              );
            },
            child: const Text('Xem danh sách đặt bàn'),
          ),
        ],
      ),
    );
  }
}
