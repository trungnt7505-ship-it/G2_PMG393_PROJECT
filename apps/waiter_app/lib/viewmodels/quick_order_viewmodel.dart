import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Trạng thái một món ăn trong giỏ hàng tạm thời của màn hình gọi món nhanh.
class QuickOrderItemCart {
  final MenuItemModel item;
  final int qty;
  final List<SelectedOption> selectedOptions;
  final String note;

  const QuickOrderItemCart({
    required this.item,
    required this.qty,
    this.selectedOptions = const [],
    this.note = '',
  });

  /// Tính tổng tiền món bao gồm các tùy chọn bổ sung (size, topping).
  int get unitPrice {
    int extraSum = 0;
    for (final opt in selectedOptions) {
      extraSum += opt.extraPrice;
    }
    return item.price + extraSum;
  }

  int get totalPrice => unitPrice * qty;

  /// Chuyển đổi thành [OrderItemModel] để gửi vào backend Firebase Firestore.
  OrderItemModel toOrderItemModel() {
    return OrderItemModel(
      itemId: item.id,
      name: item.name,
      unitPrice: unitPrice,
      qty: qty,
      selectedOptions: selectedOptions,
      note: note,
    );
  }

  QuickOrderItemCart copyWith({
    MenuItemModel? item,
    int? qty,
    List<SelectedOption>? selectedOptions,
    String? note,
  }) {
    return QuickOrderItemCart(
      item: item ?? this.item,
      qty: qty ?? this.qty,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      note: note ?? this.note,
    );
  }
}

/// Trạng thái của màn hình Gọi món siêu tốc [QuickOrderScreen].
class QuickOrderState {
  final List<QuickOrderItemCart> cartItems;
  final String selectedCategory;
  final String searchQuery;
  final bool isSubmitting;
  final String? errorMessage;

  const QuickOrderState({
    this.cartItems = const [],
    this.selectedCategory = 'Tất cả',
    this.searchQuery = '',
    this.isSubmitting = false,
    this.errorMessage,
  });

  int get totalAmount {
    return cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  }

  int get totalItemCount {
    return cartItems.fold(0, (sum, item) => sum + item.qty);
  }

  QuickOrderState copyWith({
    List<QuickOrderItemCart>? cartItems,
    String? selectedCategory,
    String? searchQuery,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return QuickOrderState(
      cartItems: cartItems ?? this.cartItems,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ViewModel phục vụ thao tác gọi món siêu tốc 1 tay cho Nhân viên Phục vụ.
class QuickOrderViewModel extends StateNotifier<QuickOrderState> {
  final OrderService _orderService;

  QuickOrderViewModel(this._orderService) : super(const QuickOrderState());

  /// Đặt danh mục món cần lọc.
  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Cập nhật từ khóa tìm kiếm món.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Thêm hoặc cập nhật một món vào giỏ hàng gọi món nhanh.
  void addItemToCart({
    required MenuItemModel item,
    int qty = 1,
    List<SelectedOption> selectedOptions = const [],
    String note = '',
  }) {
    final updatedCart = List<QuickOrderItemCart>.from(state.cartItems);
    final existingIndex = updatedCart.indexWhere(
      (cartItem) =>
          cartItem.item.id == item.id &&
          _areOptionsEqual(cartItem.selectedOptions, selectedOptions) &&
          cartItem.note == note,
    );

    if (existingIndex >= 0) {
      final existing = updatedCart[existingIndex];
      updatedCart[existingIndex] = existing.copyWith(qty: existing.qty + qty);
    } else {
      updatedCart.add(QuickOrderItemCart(
        item: item,
        qty: qty,
        selectedOptions: selectedOptions,
        note: note,
      ));
    }

    state = state.copyWith(cartItems: updatedCart);
  }

  /// Giảm số lượng hoặc xóa món khỏi giỏ hàng.
  void decreaseItemQty(int index) {
    if (index < 0 || index >= state.cartItems.length) return;
    final updatedCart = List<QuickOrderItemCart>.from(state.cartItems);
    final item = updatedCart[index];
    if (item.qty > 1) {
      updatedCart[index] = item.copyWith(qty: item.qty - 1);
    } else {
      updatedCart.removeAt(index);
    }
    state = state.copyWith(cartItems: updatedCart);
  }

  /// Xóa toàn bộ giỏ hàng hiện tại.
  void clearCart() {
    state = state.copyWith(cartItems: []);
  }

  /// Gửi đơn gọi món của nhân viên vào hệ thống.
  /// Đơn do nhân viên đặt tự động có trạng thái [OrderStatus.confirmed] và cộng thẳng vào subtotal của phiên bàn.
  Future<bool> submitOrder({
    required String sessionId,
    required String tableId,
    required String tableName,
    required String waiterUid,
  }) async {
    if (state.cartItems.isEmpty) return false;
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final orderItems =
          state.cartItems.map((cartItem) => cartItem.toOrderItemModel()).toList();

      await _orderService.submitOrder(
        sessionId: sessionId,
        tableId: tableId,
        tableName: tableName,
        items: orderItems,
        createdBy: waiterUid,
        createdByRole: 'waiter',
        type: OrderType.dine_in,
      );

      state = state.copyWith(cartItems: [], isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  bool _areOptionsEqual(
    List<SelectedOption> a,
    List<SelectedOption> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].groupName != b[i].groupName ||
          a[i].choiceName != b[i].choiceName) {
        return false;
      }
    }
    return true;
  }
}

/// Provider cho [QuickOrderViewModel].
final quickOrderViewModelProvider =
    StateNotifierProvider<QuickOrderViewModel, QuickOrderState>((ref) {
  final orderService = ref.watch(orderServiceProvider);
  return QuickOrderViewModel(orderService);
});
