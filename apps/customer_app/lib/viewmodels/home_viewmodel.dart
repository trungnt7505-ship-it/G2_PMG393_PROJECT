import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import '../repositories/customer_repository.dart';

/// Trạng thái của màn hình chính Home.
class HomeState {
  final String selectedCategory;
  final String searchQuery;
  final List<OrderItemModel> draftCart;
  final bool isSubmittingOrder;
  final String? orderError;
  final String? orderSuccess;

  const HomeState({
    this.selectedCategory = 'Tất cả',
    this.searchQuery = '',
    this.draftCart = const [],
    this.isSubmittingOrder = false,
    this.orderError,
    this.orderSuccess,
  });

  HomeState copyWith({
    String? selectedCategory,
    String? searchQuery,
    List<OrderItemModel>? draftCart,
    bool? isSubmittingOrder,
    String? orderError,
    String? orderSuccess,
    bool clearOrderMessages = false,
  }) {
    return HomeState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      draftCart: draftCart ?? this.draftCart,
      isSubmittingOrder: isSubmittingOrder ?? this.isSubmittingOrder,
      orderError: clearOrderMessages ? null : (orderError ?? this.orderError),
      orderSuccess:
          clearOrderMessages ? null : (orderSuccess ?? this.orderSuccess),
    );
  }

  int get draftCartTotal =>
      draftCart.fold(0, (total, item) => total + item.totalPrice);
}

/// ViewModel quản lý màn hình chính của khách hàng.
class HomeViewModel extends StateNotifier<HomeState> {
  final CustomerRepository _repository;

  HomeViewModel({required CustomerRepository repository})
      : _repository = repository,
        super(const HomeState());

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void addToCart(OrderItemModel item) {
    state = state.copyWith(
      draftCart: [...state.draftCart, item],
      clearOrderMessages: true,
    );
  }

  void removeFromCart(int index) {
    if (index < 0 || index >= state.draftCart.length) return;
    final updated = List<OrderItemModel>.from(state.draftCart)..removeAt(index);
    state = state.copyWith(draftCart: updated, clearOrderMessages: true);
  }

  void clearCart() {
    state = state.copyWith(draftCart: const [], clearOrderMessages: true);
  }

  Future<bool> submitOrder({
    required SessionModel session,
    required String uid,
  }) async {
    if (state.draftCart.isEmpty || state.isSubmittingOrder) return false;
    state = state.copyWith(isSubmittingOrder: true, clearOrderMessages: true);
    try {
      await _repository.submitOrder(
        sessionId: session.id,
        tableId: session.tableId,
        tableName: session.tableName,
        items: state.draftCart,
        createdBy: uid,
      );
      final itemCount = state.draftCart.length;
      state = state.copyWith(
        isSubmittingOrder: false,
        draftCart: const [],
        orderSuccess:
            'Đã gửi $itemCount món đến nhân viên phục vụ để xác nhận.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmittingOrder: false,
        orderError: 'Không thể gửi đơn món: $e',
      );
      return false;
    }
  }

  Future<bool> submitTakeawayOrder({
    required String uid,
    required String customerName,
    required String customerPhone,
    required DateTime pickupAt,
  }) async {
    if (state.draftCart.isEmpty || state.isSubmittingOrder) return false;
    state = state.copyWith(isSubmittingOrder: true, clearOrderMessages: true);
    try {
      await _repository.submitTakeawayOrder(
        items: state.draftCart,
        createdBy: uid,
        customerName: customerName,
        customerPhone: customerPhone,
        pickupAt: pickupAt,
      );
      final itemCount = state.draftCart.length;
      state = state.copyWith(
        isSubmittingOrder: false,
        draftCart: const [],
        orderSuccess: 'Đã gửi $itemCount món mang đi, hẹn nhận lúc '
            '${pickupAt.hour.toString().padLeft(2, '0')}:'
            '${pickupAt.minute.toString().padLeft(2, '0')}.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmittingOrder: false,
        orderError: 'Không thể gửi đơn mang đi: $e',
      );
      return false;
    }
  }
}

/// Provider cho HomeViewModel.
final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(
    repository: ref.watch(customerRepositoryProvider),
  );
});

/// Provider lọc danh sách món ăn theo danh mục và tìm kiếm.
final filteredMenuItemsProvider =
    Provider<AsyncValue<List<MenuItemModel>>>((ref) {
  final menuAsync = ref.watch(menuItemsProvider);
  final homeState = ref.watch(homeViewModelProvider);

  return menuAsync.whenData((items) {
    return items.where((item) {
      final matchesCategory = homeState.selectedCategory == 'Tất cả' ||
          item.category.toLowerCase() ==
              homeState.selectedCategory.toLowerCase();
      final matchesQuery = homeState.searchQuery.isEmpty ||
          item.name.toLowerCase().contains(homeState.searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  });
});
