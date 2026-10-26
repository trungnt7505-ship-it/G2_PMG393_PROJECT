import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';
import '../viewmodels/quick_order_viewmodel.dart';
import '../widgets/item_option_picker_dialog.dart';

/// Màn hình Gọi món siêu tốc 1-tay dành cho Nhân viên Phục vụ [QuickOrderScreen] (Phụ trách TRUNG).
class QuickOrderScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String tableId;
  final String tableName;

  const QuickOrderScreen({
    super.key,
    required this.sessionId,
    required this.tableId,
    required this.tableName,
  });

  @override
  ConsumerState<QuickOrderScreen> createState() => _QuickOrderScreenState();
}

class _QuickOrderScreenState extends ConsumerState<QuickOrderScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    final orderState = ref.watch(quickOrderViewModelProvider);
    final orderViewModel = ref.read(quickOrderViewModelProvider.notifier);

    final currentUser = currentUserAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Đặt món cho ${widget.tableName}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (orderState.cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: () => orderViewModel.clearCart(),
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              label: const Text('Xóa đơn', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: menuItemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi tải thực đơn: $err')),
        data: (allMenuItems) {
          // Lấy danh mục độc nhất
          final categories = [
            'Tất cả',
            ...allMenuItems.map((m) => m.category).toSet()
          ];

          // Lọc món theo danh mục và từ khóa tìm kiếm
          final filteredItems = allMenuItems.where((item) {
            final matchCategory = orderState.selectedCategory == 'Tất cả' ||
                item.category == orderState.selectedCategory;
            final matchSearch = orderState.searchQuery.isEmpty ||
                item.name
                    .toLowerCase()
                    .contains(orderState.searchQuery.toLowerCase());
            return matchCategory && matchSearch && item.available;
          }).toList();

          return Column(
            children: [
              // Thanh Lọc Danh mục và Ô Tìm kiếm
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm món ăn, đồ uống...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  orderViewModel.setSearchQuery('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.all(10),
                      ),
                      onChanged: (val) => orderViewModel.setSearchQuery(val),
                    ),
                    const SizedBox(height: 8),

                    // ChoiceChips chọn danh mục
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = orderState.selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 12,
                              ),
                              onSelected: (_) =>
                                  orderViewModel.setCategory(cat),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Thông báo lỗi nếu gửi đơn lỗi
              if (orderState.errorMessage != null)
                Container(
                  color: Colors.red.shade100,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    orderState.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              // Lưới danh sách món
              Expanded(
                child: filteredItems.isEmpty
                    ? const Center(
                        child: Text('Không tìm thấy món ăn phù hợp.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.25,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) {
                                    return ItemOptionPickerDialog(
                                      item: item,
                                      onConfirm: (options, note, qty) {
                                        orderViewModel.addItemToCart(
                                          item: item,
                                          qty: qty,
                                          selectedOptions: options,
                                          note: note,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.local_cafe_rounded,
                                            color: AppColors.primaryDark,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          currencyFormatter.format(item.price),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),

      // Thanh tổng quan đơn hàng & Nút Gửi đơn cố định ở chân màn hình
      bottomNavigationBar: orderState.cartItems.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Xem tóm tắt danh sách món trong giỏ
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: orderState.cartItems.length,
                      itemBuilder: (context, index) {
                        final cartItem = orderState.cartItems[index];
                        final optionsText = cartItem.selectedOptions
                            .map((opt) => opt.choiceName)
                            .where((s) => s.isNotEmpty)
                            .join(', ');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '${cartItem.qty}x ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                              Expanded(
                                child: Text(
                                  '${cartItem.item.name} ${optionsText.isNotEmpty ? "($optionsText)" : ""} ${cartItem.note.isNotEmpty ? "[${cartItem.note}]" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                currencyFormatter.format(cartItem.totalPrice),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () => orderViewModel
                                    .decreaseItemQty(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 12),

                  // Nút Gửi Đơn
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: orderState.isSubmitting
                          ? null
                          : () async {
                              final ok = await orderViewModel.submitOrder(
                                sessionId: widget.sessionId,
                                tableId: widget.tableId,
                                tableName: widget.tableName,
                                waiterUid: currentUser?.id ?? 'waiter_demo',
                              );

                              if (ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Đã gửi đơn gọi món thành công vào bếp!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                context.pop();
                              }
                            },
                      icon: orderState.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        'GỬI ĐƠN CHẤP NHẬN (${orderState.totalItemCount} món - ${currencyFormatter.format(orderState.totalAmount)})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
