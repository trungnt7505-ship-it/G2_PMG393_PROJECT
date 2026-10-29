import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/floor_map_viewmodel.dart';

/// Cảnh báo nhìn thấy ngay trên laptop, không phụ thuộc quyền rung/thông báo OS.
class SessionAlertBanner extends ConsumerWidget {
  const SessionAlertBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(floorMapViewModelProvider.select((s) => s.now));
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.defaultConfig;
    final sessions = ref.watch(activeSessionsProvider).valueOrNull ?? [];
    final threshold = config.warnMinutes.reduce((a, b) => a > b ? a : b);
    final alerts = sessions
        .where((s) =>
            s.isActive && s.expiresAt.difference(now).inMinutes <= threshold)
        .toList();
    if (alerts.isEmpty) return const SizedBox.shrink();
    final overdue = alerts.any((s) => !s.expiresAt.isAfter(now));
    return Material(
        color: overdue ? Colors.red.shade50 : Colors.amber.shade50,
        child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                  'Cảnh báo bàn: ${alerts.map((s) => '${s.tableName} (${!s.expiresAt.isAfter(now) ? "quá giờ" : "còn ${s.expiresAt.difference(now).inMinutes} phút"})').join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: overdue
                          ? Colors.red.shade900
                          : Colors.brown.shade900)),
            )));
  }
}
