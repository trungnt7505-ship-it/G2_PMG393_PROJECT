import 'package:flutter/material.dart';
import '../screens/auth/customer_auth_screen.dart';
import '../screens/home/customer_home_screen.dart';
import '../screens/reservation/reservation_booking_screen.dart';
import '../screens/reservation/my_reservations_screen.dart';
import '../screens/scanner/table_qr_scanner_screen.dart';
import '../screens/session/active_session_screen.dart';
import '../screens/history/points_and_history_screen.dart';

/// Định tuyến toàn bộ ứng dụng Customer App.
class AppRouter {
  static const String auth = '/auth';
  static const String home = '/home';
  static const String booking = '/reservation/book';
  static const String myReservations = '/reservation/my';
  static const String scanner = '/scanner';
  static const String activeSession = '/session';
  static const String pointsAndHistory = '/history';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case auth:
        return MaterialPageRoute<void>(
          builder: (_) => const CustomerAuthScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const CustomerHomeScreen(),
          settings: settings,
        );
      case booking:
        return MaterialPageRoute<void>(
          builder: (_) => const ReservationBookingScreen(),
          settings: settings,
        );
      case myReservations:
        return MaterialPageRoute<void>(
          builder: (_) => const MyReservationsScreen(),
          settings: settings,
        );
      case scanner:
        return MaterialPageRoute<void>(
          builder: (_) => const TableQrScannerScreen(),
          settings: settings,
        );
      case activeSession:
        final sessionId = settings.arguments as String?;
        if (sessionId == null) return null;
        return MaterialPageRoute<void>(
          builder: (_) => ActiveSessionScreen(sessionId: sessionId),
          settings: settings,
        );
      case pointsAndHistory:
        return MaterialPageRoute<void>(
          builder: (_) => const PointsAndHistoryScreen(),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
