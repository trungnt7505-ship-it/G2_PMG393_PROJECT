import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

/// Trạng thái của màn hình chính Home.
class HomeState {
  final String selectedCategory;
  final String searchQuery;

  const HomeState({
    this.selectedCategory = 'Tất cả',
    this.searchQuery = '',
  });

  HomeState copyWith({
    String? selectedCategory,
    String? searchQuery,
  }) {
    return HomeState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// ViewModel quản lý màn hình chính của khách hàng.
class HomeViewModel extends StateNotifier<HomeState> {
  HomeViewModel() : super(const HomeState());

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

/// Provider cho HomeViewModel.
final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel();
});

/// Provider lọc danh sách món ăn theo danh mục và tìm kiếm.
final filteredMenuItemsProvider = Provider<AsyncValue<List<MenuItemModel>>>((ref) {
  final menuAsync = ref.watch(menuItemsProvider);
  final homeState = ref.watch(homeViewModelProvider);

  return menuAsync.whenData((items) {
    return items.where((item) {
      final matchesCategory = homeState.selectedCategory == 'Tất cả' ||
          item.category.toLowerCase() == homeState.selectedCategory.toLowerCase();
      final matchesQuery = homeState.searchQuery.isEmpty ||
          item.name.toLowerCase().contains(homeState.searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  });
});
