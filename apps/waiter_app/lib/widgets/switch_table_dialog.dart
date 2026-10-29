import 'package:flutter/material.dart';
import 'package:core/core.dart';

/// Dialog cho phép Nhân viên Phục vụ chọn bàn trống để chuyển phiên.
class SwitchTableDialog extends StatefulWidget {
  final TableModel currentTable;
  final List<TableModel> availableTables;
  final Function(TableModel targetTable) onConfirm;

  const SwitchTableDialog({
    super.key,
    required this.currentTable,
    required this.availableTables,
    required this.onConfirm,
  });

  @override
  State<SwitchTableDialog> createState() => _SwitchTableDialogState();
}

class _SwitchTableDialogState extends State<SwitchTableDialog> {
  TableModel? _selectedTable;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Chuyển bàn (${widget.currentTable.name})'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phiên hiện tại đang ở ${widget.currentTable.name}. Vui lòng chọn bàn trống mới:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (widget.availableTables.isEmpty)
              const Text(
                'Không có bàn nào đang trống trong hệ thống.',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else
              DropdownButtonFormField<TableModel>(
                initialValue: _selectedTable,
                decoration: const InputDecoration(
                  labelText: 'Chọn bàn trống mới',
                  border: OutlineInputBorder(),
                ),
                items: widget.availableTables.map((tbl) {
                  return DropdownMenuItem<TableModel>(
                    value: tbl,
                    child:
                        Text('${tbl.name} (${tbl.zone} - ${tbl.capacity} chỗ)'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTable = val;
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _selectedTable == null
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onConfirm(_selectedTable!);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Chuyển bàn ngay'),
        ),
      ],
    );
  }
}
