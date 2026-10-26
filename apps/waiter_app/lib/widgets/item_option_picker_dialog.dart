import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';

/// Dialog cho phép Nhân viên Phục vụ chọn các Tùy chọn món (Đường, Đá, Size, Topping) và ghi chú siêu tốc.
class ItemOptionPickerDialog extends StatefulWidget {
  final MenuItemModel item;
  final Function(
    List<SelectedOption> selectedOptions,
    String note,
    int qty,
  ) onConfirm;

  const ItemOptionPickerDialog({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  @override
  State<ItemOptionPickerDialog> createState() => _ItemOptionPickerDialogState();
}

class _ItemOptionPickerDialogState extends State<ItemOptionPickerDialog> {
  int _qty = 1;
  final Map<String, List<MenuItemOptionChoice>> _selectedChoicesMap = {};
  final TextEditingController _noteController = TextEditingController();

  // Nút tùy chọn nhanh ghi chú
  final List<String> _quickNotes = [
    'Ít đá',
    'Không đá',
    'Ít ngọt',
    'Không đường',
    'Không kem',
    'Mang đi',
  ];

  @override
  void initState() {
    super.initState();
    // Khởi tạo tùy chọn mặc định nếu nhóm yêu cầu bắt buộc (required)
    for (final group in widget.item.options) {
      if (group.required && group.choices.isNotEmpty) {
        _selectedChoicesMap[group.groupName] = [group.choices.first];
      } else {
        _selectedChoicesMap[group.groupName] = [];
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _toggleChoice(MenuItemOptionGroup group, MenuItemOptionChoice choice) {
    setState(() {
      final currentList = _selectedChoicesMap[group.groupName] ?? [];
      if (group.maxSelect == 1) {
        _selectedChoicesMap[group.groupName] = [choice];
      } else {
        if (currentList.any((c) => c.name == choice.name)) {
          currentList.removeWhere((c) => c.name == choice.name);
        } else {
          if (currentList.length < group.maxSelect) {
            currentList.add(choice);
          }
        }
        _selectedChoicesMap[group.groupName] = currentList;
      }
    });
  }

  void _appendQuickNote(String note) {
    final currentText = _noteController.text.trim();
    if (currentText.isEmpty) {
      _noteController.text = note;
    } else if (!currentText.contains(note)) {
      _noteController.text = '$currentText, $note';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    // Tính tổng tiền đơn giá
    int extraPrice = 0;
    for (final choices in _selectedChoicesMap.values) {
      for (final c in choices) {
        extraPrice += c.extraPrice;
      }
    }
    final unitPrice = widget.item.price + extraPrice;
    final totalPrice = unitPrice * _qty;

    return AlertDialog(
      titlePadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          Text(
            currencyFormat.format(widget.item.price),
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Các nhóm tùy chọn món (Size, Topping, etc)
              if (widget.item.options.isNotEmpty) ...[
                ...widget.item.options.map((group) {
                  final selectedList =
                      _selectedChoicesMap[group.groupName] ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${group.groupName} ${group.required ? "(*Bắt buộc)" : ""}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: group.choices.map((choice) {
                          final isSelected = selectedList
                              .any((c) => c.name == choice.name);
                          return FilterChip(
                            selected: isSelected,
                            label: Text(
                              choice.extraPrice > 0
                                  ? '${choice.name} (+${currencyFormat.format(choice.extraPrice)})'
                                  : choice.name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            selectedColor: AppColors.primary,
                            onSelected: (_) => _toggleChoice(group, choice),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
                const Divider(),
              ],

              // Ghi chú siêu tốc
              const Text(
                'Ghi chú nhanh:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _quickNotes.map((note) {
                  return ActionChip(
                    label: Text(note, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.grey.shade200,
                    onPressed: () => _appendQuickNote(note),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'Nhập ghi chú khác...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // Chọn số lượng món
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Số lượng:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _qty > 1
                            ? () => setState(() => _qty--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_qty',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => setState(() => _qty++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            final List<SelectedOption> resultOptions = [];
            _selectedChoicesMap.forEach((groupName, choices) {
              for (final choice in choices) {
                resultOptions.add(
                  SelectedOption(
                    groupName: groupName,
                    choiceName: choice.name,
                    extraPrice: choice.extraPrice,
                  ),
                );
              }
            });

            widget.onConfirm(resultOptions, _noteController.text.trim(), _qty);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text('Thêm vào đơn (${currencyFormat.format(totalPrice)})'),
        ),
      ],
    );
  }
}
