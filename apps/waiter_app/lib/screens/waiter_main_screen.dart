import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import '../viewmodels/waiter_auth_viewmodel.dart';
import 'floor_map_screen.dart';
import 'waiter_task_hub_screen.dart';

/// Màn hình chính gộp của App Nhân viên Phục vụ [WaiterMainScreen].
/// Bao gồm Thanh Navigation Bottom điều hướng giữa Sơ đồ Bàn & Trung tâm Tác vụ.
class WaiterMainScreen extends ConsumerStatefulWidget {
  const WaiterMainScreen({super.key});

  @override
  ConsumerState<WaiterMainScreen> createState() => _WaiterMainScreenState();
}

class _WaiterMainScreenState extends ConsumerState<WaiterMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    FloorMapScreen(),
    WaiterTaskHubScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authViewModelUser = ref.watch(waiterAuthViewModelProvider).value;
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUser = authViewModelUser ?? currentUserAsync.value;

    final pendingOrdersAsync = ref.watch(ordersByStatusesProvider(const [OrderStatus.pending]));
    final readyOrdersAsync = ref.watch(ordersByStatusesProvider(const [OrderStatus.ready]));
    final openRequestsAsync = ref.watch(openRequestsProvider);

    final totalBadgeCount = (pendingOrdersAsync.value?.length ?? 0) +
        (readyOrdersAsync.value?.length ?? 0) +
        (openRequestsAsync.value?.length ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person_pin_rounded, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              currentUser != null
                  ? 'Phục vụ: ${currentUser.displayName}'
                  : 'Cafe Waiter App',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await ref.read(waiterAuthViewModelProvider.notifier).signOut();
              if (mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.table_restaurant),
            label: 'Sơ đồ Bàn',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('$totalBadgeCount'),
              isLabelVisible: totalBadgeCount > 0,
              backgroundColor: Colors.red,
              child: const Icon(Icons.assignment_turned_in_outlined),
            ),
            label: 'Tác vụ',
          ),
        ],
      ),
    );
  }
}
