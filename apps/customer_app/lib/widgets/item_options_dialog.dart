import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';

/// Modal Dialog cho phép khách hàng chọn các tùy chọn (Size, Topping, Đá, Đường...)
/// và nhập ghi chú trước khi thêm vào giỏ đặt trước hoặc giỏ gọi món tại bàn.
class ItemOptionsDialog extends StatefulWidget {
  final MenuItemModel item;
  final Function(OrderItemModel orderItem) onConfirm;

  const ItemOptionsDialog({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  @override
  State<ItemOptionsDialog> createState() => _ItemOptionsDialogState();
}

class _ItemOptionsDialogState extends State<ItemOptionsDialog> {
  final _formatter = NumberFormat('#,###', 'vi_VN');
  final _noteController = TextEditingController();
  int _qty = 1;

  // Lưu trữ các tùy chọn đã chọn theo từng nhóm: groupName -> Set of MenuItemOptionChoice
  final Map<String, Set<MenuItemOptionChoice>> _selectedChoicesByGroup = {};

  @override
  void initState() {
    super.initState();
    // Khởi tạo các nhóm tùy chọn bắt buộc (chọn mặc định phần tử đầu tiên nếu là single select)
    for (final group in widget.item.options) {
      _selectedChoicesByGroup[group.groupName] = {};
      if (group.required && group.choices.isNotEmpty) {
        _selectedChoicesByGroup[group.groupName]!.add(group.choices.first);
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _extraPricePerItem {
    int sum = 0;
    for (final choices in _selectedChoicesByGroup.values) {
      for (final choice in choices) {
        sum += choice.extraPrice;
      }
    }
    return sum;
  }

  int get _totalItemPrice => (widget.item.price + _extraPricePerItem) * _qty;

  bool get _isValid {
    // Kiểm tra xem tất cả các nhóm bắt buộc (required == true) đã có ít nhất 1 lựa chọn chưa
    for (final group in widget.item.options) {
      if (group.required) {
        final selected = _selectedChoicesByGroup[group.groupName] ?? {};
        if (selected.isEmpty) return false;
      }
    }
    return true;
  }

  void _onChoiceTapped(MenuItemOptionGroup group, MenuItemOptionChoice choice) {
    setState(() {
      final currentSet = _selectedChoicesByGroup[group.groupName] ?? {};

      if (group.maxSelect == 1) {
        // Nhóm chọn 1 (ví dụ: Size M hoặc Size L)
        currentSet.clear();
        currentSet.add(choice);
      } else {
        // Nhóm chọn nhiều (ví dụ: Topping)
        if (currentSet.contains(choice)) {
          currentSet.remove(choice);
        } else {
          if (currentSet.length < group.maxSelect) {
            currentSet.add(choice);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tối đa ${group.maxSelect} lựa chọn cho ${group.groupName}'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      }
      _selectedChoicesByGroup[group.groupName] = currentSet;
    });
  }

  void _submit() {
    if (!_isValid) return;

    final selectedOptionsList = <SelectedOption>[];
    for (final entry in _selectedChoicesByGroup.entries) {
      for (final choice in entry.value) {
        selectedOptionsList.add(SelectedOption(
          groupName: entry.key,
          choiceName: choice.name,
          extraPrice: choice.extraPrice,
        ));
      }
    }

    final orderItem = OrderItemModel(
      itemId: widget.item.id,
      name: widget.item.name,
      unitPrice: widget.item.price,
      qty: _qty,
      selectedOptions: selectedOptionsList,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );

    widget.onConfirm(orderItem);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header món
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFEBE9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_cafe, color: Color(0xFF5D4037), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E2723),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatter.format(widget.item.price)} đ · ${widget.item.category}',
                          style: const TextStyle(color: Color(0xFF795548), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const Divider(height: 24),

              // Danh sách tùy chọn
              Expanded(
                child: ListView(
                  children: [
                    if (widget.item.options.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Món này không có tùy chọn bổ sung.',
                          style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ...widget.item.options.map((group) {
                      final selectedSet = _selectedChoicesByGroup[group.groupName] ?? {};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  group.groupName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF3E2723),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (group.required)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Bắt buộc',
                                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  Text(
                                    '(Tối đa ${group.maxSelect})',
                                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: group.choices.map((choice) {
                                final isSelected = selectedSet.contains(choice);
                                return FilterChip(
                                  label: Text(
                                    choice.extraPrice > 0
                                        ? '${choice.name} (+${_formatter.format(choice.extraPrice)}đ)'
                                        : choice.name,
                                  ),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFFD7CCC8),
                                  checkmarkColor: const Color(0xFF5D4037),
                                  labelStyle: TextStyle(
                                    color: isSelected ? const Color(0xFF3E2723) : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  onSelected: (_) => _onChoiceTapped(group, choice),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Ô nhập ghi chú
                    const SizedBox(height: 8),
                    const Text(
                      'Ghi chú cho quán',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3E2723)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'VD: Ít đường, nhiều đá, không sữa...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 20),

              // Chọn số lượng và nút xác nhận
              Row(
                children: [
                  // Bộ tăng giảm số lượng
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                        ),
                        Text('$_qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () => setState(() => _qty++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nút bấm xác nhận thêm
                  Expanded(
                    child: FilledButton(
                      onPressed: _isValid ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5D4037),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Thêm · ${_formatter.format(_totalItemPrice)} đ',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
