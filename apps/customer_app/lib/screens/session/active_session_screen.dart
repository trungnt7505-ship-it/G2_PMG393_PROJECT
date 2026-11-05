import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';

import '../../viewmodels/active_session_viewmodel.dart';
import '../../widgets/item_options_dialog.dart';

/// Màn hình theo dõi phiên bàn đang dùng của khách hàng (ActiveSessionScreen) - MVVM.
///
/// Tính năng:
/// 1. Theo dõi realtime thông tin phiên bàn qua [sessionStreamProvider].
/// 2. Đồng hồ đếm ngược [CountdownTimerWidget] kết nối đồng bộ [AlarmService].
/// 3. Thao tác phiên bàn: Gia hạn (+30'), Xin trả bàn sớm (nhận điểm thưởng), Gọi phục vụ, Yêu cầu hóa đơn.
/// 4. Gọi thêm món kèm tùy chọn (Options & Note) và đưa vào giỏ gọi thêm trước khi gửi bếp ('pending').
/// 5. Theo dõi tiến độ pha chế và phục vụ của từng đơn hàng trong phiên.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ActiveSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  final _formatter = NumberFormat('#,###', 'vi_VN');
  bool _alarmReady = false;
  Timer? _alarmTicker;
  StreamSubscription<SessionAlarm>? _alarmSubscription;
  SessionAlarm? _latestAlarm;
  DateTime? _observedExpiry;
  final Set<String> _handledReleaseRequestIds = {};

  @override
  void initState() {
    super.initState();
    _alarmSubscription = ref.read(alarmServiceProvider).alerts.listen((alarm) {
      if (!mounted || alarm.sessionId != widget.sessionId) return;
      setState(() => _latestAlarm = alarm);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${alarm.title}\n${alarm.body}'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: 'Đã hiểu', onPressed: () {}),
      ));
      if (alarm.title.toLowerCase().contains('nhả bàn') || alarm.title.toLowerCase().contains('hết giờ')) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
            title: Text(alarm.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(alarm.body, style: const TextStyle(fontSize: 15)),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
      }
    });
    _alarmTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    ref.read(alarmServiceProvider).init().then((_) {
      if (mounted) setState(() => _alarmReady = true);
    }).catchError((_) {
      if (mounted) setState(() => _alarmReady = true);
    });
  }

  @override
  void dispose() {
    _alarmTicker?.cancel();
    _alarmSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStreamProvider(widget.sessionId));
    final ordersAsync = ref.watch(sessionOrdersProvider(widget.sessionId));
    final menuAsync = ref.watch(menuItemsProvider);
    final requests = ref.watch(openRequestsProvider);
    final extensionRequests = ref.watch(extensionRequestsProvider(widget.sessionId));
    final config = ref.watch(appConfigProvider).value ?? AppConfig.defaultConfig;
    final uid = ref.watch(authServiceProvider).currentUid ?? '';
    final sessionState = ref.watch(activeSessionViewModelProvider);
    final vm = ref.read(activeSessionViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiên bàn của bạn'),
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Không tải được phiên bàn: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Phiên bàn không còn tồn tại hoặc đã đóng.'));
          }

          // Đồng bộ báo động trên thiết bị
          if (_observedExpiry != session.expiresAt) {
            _observedExpiry = session.expiresAt;
            _latestAlarm = null;
          }
          if (_alarmReady) {
            ref.read(alarmServiceProvider).syncAlarmsForSession(session, config: config);
            final releaseReqs = requests.valueOrNull?.where((r) => r.sessionId == session.id && r.type == 'release_table') ?? [];
            for (final req in releaseReqs) {
              if (_handledReleaseRequestIds.add(req.id)) {
                ref.read(alarmServiceProvider).triggerDirectAlert(
                  sessionId: session.id,
                  title: 'Nhân viên yêu cầu nhả bàn!',
                  body: req.message.isNotEmpty ? req.message : 'Nhân viên xin phép mời bạn chuẩn bị nhả bàn để phục vụ lượt khách kế tiếp.',
                  alertId: req.id,
                );
              }
            }
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  if (_latestAlarm != null && session.isActive &&
                      session.expiresAt.difference(ClockService.instance.serverNow) <=
                          Duration(minutes: config.warnMinutes.isEmpty ? 0 : config.warnMinutes.reduce((a, b) => a > b ? a : b)))
                    _buildMessageBanner('${_latestAlarm!.title}\n${_latestAlarm!.body}', isError: true),
                  ...?extensionRequests.valueOrNull?.map((r) => _buildMessageBanner(
                    r['status'] == 'open' ? 'Yêu cầu gia hạn: đang chờ nhân viên duyệt.' : r['decision'] == 'approved' ? 'Đã duyệt gia hạn thêm ${r['approvedMinutes']} phút.' : 'Nhân viên đã từ chối gia hạn. Vui lòng liên hệ phục vụ.', isError: r['decision'] == 'rejected')),
                  ...?requests.valueOrNull?.where((r) => r.sessionId == session.id && r.type == 'release_table').map(
                    (r) => _buildMessageBanner('Nhân viên yêu cầu nhả bàn: ${r.message}', isError: true)),
                  if (session.isActive && !session.expiresAt.isAfter(ClockService.instance.serverNow))
                    _buildMessageBanner('Đã hết thời gian sử dụng bàn. Vui lòng gia hạn hoặc yêu cầu tính tiền.', isError: true),
                  // Thông báo lỗi / thành công từ ViewModel
                  if (sessionState.actionError != null)
                    _buildMessageBanner(sessionState.actionError!, isError: true),
                  if (sessionState.actionSuccess != null)
                    _buildMessageBanner(sessionState.actionSuccess!, isError: false),

                  // 1. Thẻ thông tin phiên bàn & Đồng hồ đếm ngược
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.tableName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3E2723),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Bắt đầu: ${DateFormat('HH:mm').format(session.startedAt)}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                                  ),
                                ],
                              ),
                              _buildSessionStatusTag(session.status),
                            ],
                          ),
                          const Divider(height: 28),
                          if (!session.isActive)
                            const Text('Phiên bàn đã kết thúc', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                          else CountdownTimerWidget(
                            expiresAt: session.expiresAt,
                            fontSize: 34,
                            warningMinutes: config.warnMinutes.isNotEmpty
                                ? config.warnMinutes.first
                                : 15,
                            extendStepMinutes: config.extendStepMinutes,
                            onExtend: session.isActive
                                ? () => vm.extendSession(session.id, uid)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tạm tính hiện tại: ${_formatter.format(session.subtotal)} đ',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Bốn nút tương tác nghiệp vụ chính
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.more_time,
                          label: 'Xin gia hạn',
                          color: const Color(0xFFE65100),
                          isLoading: sessionState.isActionLoading,
                          onTap: session.isActive
                              ? () => vm.extendSession(session.id, uid)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.exit_to_app,
                          label: 'Xin trả sớm',
                          color: const Color(0xFF2E7D32),
                          isLoading: sessionState.isActionLoading,
                          onTap: session.isActive
                              ? () => _confirmEarlyRelease(context, vm, session.id, uid)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.room_service_outlined,
                          label: 'Gọi phục vụ',
                          color: const Color(0xFF0277BD),
                          isLoading: sessionState.isActionLoading,
                          onTap: session.isActive
                              ? () => vm.callWaiter(
                                    sessionId: session.id,
                                    tableId: session.tableId,
                                    tableName: session.tableName,
                                    uid: uid,
                                  )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.receipt_long,
                          label: 'Yêu cầu tính tiền',
                          color: const Color(0xFF4E342E),
                          isLoading: sessionState.isActionLoading,
                          onTap: session.isActive
                              ? () => vm.requestBill(
                                    sessionId: session.id,
                                    tableId: session.tableId,
                                    tableName: session.tableName,
                                    uid: uid,
                                  )
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. Giỏ món gọi thêm hiện tại (Draft Cart)
                  if (sessionState.draftCart.isNotEmpty) ...[
                    Card(
                      color: const Color(0xFFFFF8E1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFFFE082)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shopping_cart, color: Color(0xFFE65100), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Món đang chọn (${sessionState.draftCart.length})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: vm.clearDraftCart,
                                  child: const Text('Xóa hết', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              ],
                            ),
                            const Divider(),
                            ...sessionState.draftCart.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Text('${item.qty}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          if (item.selectedOptions.isNotEmpty)
                                            Text(
                                              item.selectedOptions.map((o) => o.choiceName).join(', '),
                                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text('${_formatter.format(item.totalPrice)} đ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                                      onPressed: () => vm.removeFromDraftCart(idx),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: sessionState.isActionLoading
                                  ? null
                                  : () => vm.submitDraftCart(
                                        sessionId: session.id,
                                        tableId: session.tableId,
                                        tableName: session.tableName,
                                        uid: uid,
                                      ),
                              icon: const Icon(Icons.send),
                              label: Text('Gửi đơn gọi món · ${_formatter.format(sessionState.draftCartTotal)} đ'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF5D4037),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 4. Danh sách các đơn đã đặt của phiên
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Các đơn đã gửi của bàn',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Gọi thêm món', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5D4037),
                          side: const BorderSide(color: Color(0xFFBCAAA4)),
                        ),
                        onPressed: session.isActive
                            ? () => _showAddMenuModal(context, menuAsync, vm)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ordersAsync.when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text(
                            'Chưa có đơn gọi món nào trong phiên.',
                            style: TextStyle(color: Colors.black45),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final order = orders[idx];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Đơn #${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      _buildOrderStatusBadge(order.status),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  ...order.items.map((i) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          children: [
                                            Text('${i.qty}x ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(i.name, style: const TextStyle(fontSize: 13)),
                                                  if (i.selectedOptions.isNotEmpty)
                                                    Text(
                                                      i.selectedOptions.map((o) => o.choiceName).join(', '),
                                                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                    ),
                                                  if (i.note != null && i.note!.isNotEmpty)
                                                    Text('Ghi chú: ${i.note}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black45)),
                                                ],
                                              ),
                                            ),
                                            Text('${_formatter.format(i.totalPrice)} đ', style: const TextStyle(fontSize: 13)),
                                          ],
                                        ),
                                      )),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Tổng tiền đơn:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(
                                        '${_formatter.format(order.total)} đ',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF5D4037)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Lỗi tải đơn hàng: $e'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBanner(String text, {required bool isError}) {
    final color = isError ? Colors.red : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(text, style: TextStyle(color: color.shade900, fontSize: 13)),
    );
  }

  Widget _buildSessionStatusTag(String status) {
    final isBilling = status == 'billing';
    final color = isBilling ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
    final label = switch (status) {
      'billing' => 'Chờ thanh toán',
      'paid' => 'Đã thanh toán',
      'cancelled' => 'Đã hủy',
      _ => 'Đang hoạt động',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildOrderStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = const Color(0xFFF57C00);
        label = 'Chờ duyệt';
        break;
      case 'confirmed':
        color = const Color(0xFF0288D1);
        label = 'Đã duyệt';
        break;
      case 'preparing':
        color = const Color(0xFF7B1FA2);
        label = 'Đang pha chế';
        break;
      case 'ready':
        color = const Color(0xFF388E3C);
        label = 'Đã xong';
        break;
      case 'served':
        color = const Color(0xFF2E7D32);
        label = 'Đã phục vụ';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Đã hủy';
        break;
      default:
        color = Colors.black54;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  void _showAddMenuModal(
    BuildContext context,
    AsyncValue<List<MenuItemModel>> menuAsync,
    ActiveSessionViewModel vm,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
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
                'Thực đơn gọi thêm tại bàn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Expanded(
              child: menuAsync.when(
                data: (items) {
                  final available = items.where((i) => i.available).toList();
                  if (available.isEmpty) {
                    return const Center(child: Text('Không có món khả dụng.'));
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
                                vm.addToDraftCart(orderItem);
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

  Future<void> _confirmEarlyRelease(
    BuildContext context,
    ActiveSessionViewModel vm,
    String sessionId,
    String uid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xin trả bàn sớm'),
        content: const Text(
          'Bạn có chắc chắn muốn trả bàn sớm không? Bạn sẽ được tặng thêm điểm thưởng khi thanh toán hóa đơn tại quầy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận trả sớm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await vm.requestEarlyRelease(sessionId, uid);
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECE5DE)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: onTap == null ? Colors.grey : color, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: onTap == null ? Colors.grey : color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
