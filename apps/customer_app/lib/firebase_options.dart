import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show kIsWeb;

/// Firebase options for the customer app. Android must be generated for its own
/// application ID (`com.cafe.customer_app`) with FlutterFire before use.
class CustomerFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Customer Firebase options are not configured for this platform. '
      'Run flutterfire configure for the customer app.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDC5m684x2DNEZRuniQcQmkP4Oo5K9SHzY',
    appId: '1:881262711524:web:8dcdb9bf625587859f52f1',
    messagingSenderId: '881262711524',
    projectId: 'cafe-73637',
    authDomain: 'cafe-73637.firebaseapp.com',
    storageBucket: 'cafe-73637.firebasestorage.app',
    measurementId: 'G-PVT3002JK7',
  );
}
