import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';
import '../screens/session/active_session_screen.dart';

/// Thẻ hiển thị phiên bàn đang hoạt động ngay trên trang chủ của khách hàng.
/// Giúp khách hàng nắm bắt được thời gian còn lại và dễ dàng truy cập lại bàn để gọi món hoặc xin hỗ trợ.
class ActiveSessionBanner extends StatelessWidget {
  final SessionModel session;
  final AppConfig config;

  const ActiveSessionBanner({
    super.key,
    required this.session,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3E2723), Color(0xFF5D4037)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x333E2723),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ActiveSessionScreen(sessionId: session.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.table_restaurant,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BÀN BẠN ĐANG DÙNG',
                              style: TextStyle(
                                color: Color(0xFFD7CCC8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              session.tableName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.status == 'billing'
                            ? AppColors.statusExpiring.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        session.status == 'billing' ? 'Chờ thanh toán' : 'Đang phục vụ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thời gian còn lại',
                            style: TextStyle(color: Color(0xFFD7CCC8), fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          CountdownTimerWidget(
                            expiresAt: session.expiresAt,
                            fontSize: 20,
                            warningMinutes: config.warnMinutes.isNotEmpty
                                ? config.warnMinutes.first
                                : 15,
                            extendStepMinutes: config.extendStepMinutes,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Tạm tính',
                            style: TextStyle(color: Color(0xFFD7CCC8), fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatter.format(session.subtotal)} đ',
                            style: const TextStyle(
                              color: Color(0xFFFFCC80),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Bấm để gọi thêm món, gia hạn hoặc gọi phục vụ',
                      style: TextStyle(
                        color: Color(0xFFD7CCC8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFFD7CCC8)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
