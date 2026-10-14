/// Lựa chọn cụ thể trong một nhóm tùy chọn (Topping, Size...).
class MenuItemOptionChoice {
  /// Tên lựa chọn (VD: "Size L", "Thêm Trân Châu").
  final String name;

  /// Giá phụ thu VND (VD: 5000, 10000).
  final int extraPrice;

  const MenuItemOptionChoice({
    required this.name,
    this.extraPrice = 0,
  });

  factory MenuItemOptionChoice.fromMap(Map<String, dynamic> map) {
    return MenuItemOptionChoice(
      name: map['name'] as String? ?? '',
      extraPrice: (map['extraPrice'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'extraPrice': extraPrice,
    };
  }

  MenuItemOptionChoice copyWith({
    String? name,
    int? extraPrice,
  }) {
    return MenuItemOptionChoice(
      name: name ?? this.name,
      extraPrice: extraPrice ?? this.extraPrice,
    );
  }
}

/// Nhóm tùy chọn cho món ăn/nước uống (VD: "Chọn Size", "Chọn Topping").
class MenuItemOptionGroup {
  /// Tên nhóm tùy chọn.
  final String groupName;

  /// Bắt buộc phải chọn hay không (VD: Size là bắt buộc, Topping là tùy chọn).
  final bool required;

  /// Số lượng lựa chọn tối đa trong nhóm (VD: 1 đối với Size, 3 đối với Topping).
  final int maxSelect;

  /// Danh sách các lựa chọn trong nhóm này.
  final List<MenuItemOptionChoice> choices;

  const MenuItemOptionGroup({
    required this.groupName,
    this.required = false,
    this.maxSelect = 1,
    this.choices = const [],
  });

  factory MenuItemOptionGroup.fromMap(Map<String, dynamic> map) {
    return MenuItemOptionGroup(
      groupName: map['groupName'] as String? ?? '',
      required: map['required'] as bool? ?? false,
      maxSelect: (map['maxSelect'] as num?)?.toInt() ?? 1,
      choices: (map['choices'] as List<dynamic>?)
              ?.map((e) => MenuItemOptionChoice.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupName': groupName,
      'required': required,
      'maxSelect': maxSelect,
      'choices': choices.map((e) => e.toMap()).toList(),
    };
  }

  MenuItemOptionGroup copyWith({
    String? groupName,
    bool? required,
    int? maxSelect,
    List<MenuItemOptionChoice>? choices,
  }) {
    return MenuItemOptionGroup(
      groupName: groupName ?? this.groupName,
      required: required ?? this.required,
      maxSelect: maxSelect ?? this.maxSelect,
      choices: choices ?? this.choices,
    );
  }
}

/// Món trong thực đơn quán Cafe.
/// Firestore path: `menuItems/{itemId}`.
class MenuItemModel {
  /// Mã định danh món (VD: "item_cf_den").
  final String id;

  /// Tên món (VD: "Cà phê đen đá").
  final String name;

  /// Giá cơ bản VND (VD: 30000).
  final int price;

  /// Danh mục (VD: "Cà phê", "Trà trái cây", "Bánh ngọt").
  final String category;

  /// Đường dẫn hình ảnh món.
  final String imageUrl;

  /// Trạng thái còn hàng / có thể đặt.
  final bool available;

  /// Danh sách các nhóm tùy chọn (Size, Đường/Đá, Topping).
  final List<MenuItemOptionGroup> options;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl = '',
    this.available = true,
    this.options = const [],
  });

  /// Khởi tạo MenuItemModel từ Firestore Map.
  factory MenuItemModel.fromMap(Map<String, dynamic> map, String id) {
    return MenuItemModel(
      id: id,
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      available: map['available'] as bool? ?? true,
      options: (map['options'] as List<dynamic>?)
              ?.map((e) => MenuItemOptionGroup.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  /// Chuyển đối tượng thành Map để lưu trữ trên Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'available': available,
      'options': options.map((e) => e.toMap()).toList(),
    };
  }

  /// Tạo bản sao có cập nhật thuộc tính.
  MenuItemModel copyWith({
    String? id,
    String? name,
    int? price,
    String? category,
    String? imageUrl,
    bool? available,
    List<MenuItemOptionGroup>? options,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      available: available ?? this.available,
      options: options ?? this.options,
    );
  }
}

