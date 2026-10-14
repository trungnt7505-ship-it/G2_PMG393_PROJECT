import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_config.dart';
import '../models/menu_item_model.dart';
import '../models/table_model.dart';

/// Dịch vụ khởi tạo dữ liệu mẫu ban đầu cho toàn bộ hệ thống quán Cafe (Seed Data).
class SeedService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  SeedService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  /// Tự động kiểm tra và khởi tạo dữ liệu mẫu nếu Firestore còn trống:
  /// - Document cấu hình `config/app`
  /// - 12 bàn mẫu phân bố tại Tầng 1 và Tầng 2
  /// - 10 món nước và bánh ngọt kèm các tùy chọn Size và Topping
  Future<void> seedInitialDataIfEmpty() async {
    // 1. Khởi tạo config/app nếu chưa có
    final configDoc = await _firestore.collection('config').doc('app').get();
    if (!configDoc.exists) {
      await _firestore
          .collection('config')
          .doc('app')
          .set(AppConfig.defaultConfig.toMap());
    }

    // 2. Khởi tạo 12 bàn mẫu nếu chưa có bàn nào
    final tablesSnapshot = await _firestore.collection('tables').limit(1).get();
    if (tablesSnapshot.docs.isEmpty) {
      final sampleTables = <TableModel>[
        // Tầng 1 (6 bàn)
        const TableModel(
          id: 'table_01',
          name: 'Bàn 01',
          zone: 'Tầng 1',
          capacity: 2,
          qrSecret: 'sec_t1_01',
        ),
        const TableModel(
          id: 'table_02',
          name: 'Bàn 02',
          zone: 'Tầng 1',
          capacity: 2,
          qrSecret: 'sec_t1_02',
        ),
        const TableModel(
          id: 'table_03',
          name: 'Bàn 03',
          zone: 'Tầng 1',
          capacity: 4,
          qrSecret: 'sec_t1_03',
        ),
        const TableModel(
          id: 'table_04',
          name: 'Bàn 04',
          zone: 'Tầng 1',
          capacity: 4,
          qrSecret: 'sec_t1_04',
        ),
        const TableModel(
          id: 'table_05',
          name: 'Bàn 05',
          zone: 'Tầng 1',
          capacity: 6,
          qrSecret: 'sec_t1_05',
        ),
        const TableModel(
          id: 'table_06',
          name: 'Bàn 06',
          zone: 'Tầng 1',
          capacity: 6,
          qrSecret: 'sec_t1_06',
        ),

        // Tầng 2 (6 bàn)
        const TableModel(
          id: 'table_07',
          name: 'Bàn 07',
          zone: 'Tầng 2',
          capacity: 2,
          qrSecret: 'sec_t2_07',
        ),
        const TableModel(
          id: 'table_08',
          name: 'Bàn 08',
          zone: 'Tầng 2',
          capacity: 2,
          qrSecret: 'sec_t2_08',
        ),
        const TableModel(
          id: 'table_09',
          name: 'Bàn 09',
          zone: 'Tầng 2',
          capacity: 4,
          qrSecret: 'sec_t2_09',
        ),
        const TableModel(
          id: 'table_10',
          name: 'Bàn 10',
          zone: 'Tầng 2',
          capacity: 4,
          qrSecret: 'sec_t2_10',
        ),
        const TableModel(
          id: 'table_11',
          name: 'Bàn 11',
          zone: 'Tầng 2',
          capacity: 8,
          qrSecret: 'sec_t2_11',
        ),
        const TableModel(
          id: 'table_12',
          name: 'Bàn 12',
          zone: 'Tầng 2',
          capacity: 8,
          qrSecret: 'sec_t2_12',
        ),
      ];

      final batch = _firestore.batch();
      for (final table in sampleTables) {
        final ref = _firestore.collection('tables').doc(table.id);
        batch.set(ref, table.toMap());
      }
      await batch.commit();
    }

    // 3. Khởi tạo 10 món nước / bánh mẫu nếu thực đơn còn trống
    final menuSnapshot = await _firestore.collection('menuItems').limit(1).get();
    if (menuSnapshot.docs.isEmpty) {
      const sizeOptions = MenuItemOptionGroup(
        groupName: 'Kích cỡ (Size)',
        required: true,
        maxSelect: 1,
        choices: [
          MenuItemOptionChoice(name: 'Size Vừa (M)', extraPrice: 0),
          MenuItemOptionChoice(name: 'Size Lớn (L)', extraPrice: 6000),
        ],
      );

      const toppingOptions = MenuItemOptionGroup(
        groupName: 'Topping thêm',
        required: false,
        maxSelect: 3,
        choices: [
          MenuItemOptionChoice(name: 'Trân châu trắng', extraPrice: 8000),
          MenuItemOptionChoice(name: 'Thạch củ năng', extraPrice: 8000),
          MenuItemOptionChoice(name: 'Kem Cheese béo ngậy', extraPrice: 12000),
        ],
      );

      final sampleMenuItems = <MenuItemModel>[
        const MenuItemModel(
          id: 'item_01',
          name: 'Cà phê đen đá',
          price: 29000,
          category: 'Cà phê',
          imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=500',
          available: true,
          options: [sizeOptions],
        ),
        const MenuItemModel(
          id: 'item_02',
          name: 'Cà phê sữa đá Sài Gòn',
          price: 35000,
          category: 'Cà phê',
          imageUrl: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=500',
          available: true,
          options: [sizeOptions],
        ),
        const MenuItemModel(
          id: 'item_03',
          name: 'Bạc xỉu 3 tầng',
          price: 39000,
          category: 'Cà phê',
          imageUrl: 'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=500',
          available: true,
          options: [sizeOptions],
        ),
        const MenuItemModel(
          id: 'item_04',
          name: 'Trà đào cam sả',
          price: 45000,
          category: 'Trà trái cây',
          imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500',
          available: true,
          options: [sizeOptions, toppingOptions],
        ),
        const MenuItemModel(
          id: 'item_05',
          name: 'Trà vải hoa hồng tuyết',
          price: 49000,
          category: 'Trà trái cây',
          imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500',
          available: true,
          options: [sizeOptions, toppingOptions],
        ),
        const MenuItemModel(
          id: 'item_06',
          name: 'Matcha Latte Nhật Bản',
          price: 52000,
          category: 'Trà sữa',
          imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=500',
          available: true,
          options: [sizeOptions, toppingOptions],
        ),
        const MenuItemModel(
          id: 'item_07',
          name: 'Trà sữa trân châu hoàng gia',
          price: 45000,
          category: 'Trà sữa',
          imageUrl: 'https://images.unsplash.com/photo-1558857563-b371b2650041?w=500',
          available: true,
          options: [sizeOptions, toppingOptions],
        ),
        const MenuItemModel(
          id: 'item_08',
          name: 'Sinh tố xoài cốt dừa',
          price: 55000,
          category: 'Sinh tố',
          imageUrl: 'https://images.unsplash.com/photo-1623065422902-30a2d299bbe4?w=500',
          available: true,
          options: [sizeOptions],
        ),
        const MenuItemModel(
          id: 'item_09',
          name: 'Bánh Croissant bơ tỏi nướng',
          price: 35000,
          category: 'Bánh ngọt',
          imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500',
          available: true,
        ),
        const MenuItemModel(
          id: 'item_10',
          name: 'Bánh Tiramisu Ý truyền thống',
          price: 45000,
          category: 'Bánh ngọt',
          imageUrl: 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=500',
          available: true,
        ),
      ];

      final batch = _firestore.batch();
      for (final item in sampleMenuItems) {
        final ref = _firestore.collection('menuItems').doc(item.id);
        batch.set(ref, item.toMap());
      }
      await batch.commit();
    }
  }
}
