import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Firebase configuration for Customer Web and Android (com.cafe.customer_app).
class CustomerFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'Customer Firebase options are not configured for this platform. '
      'Run flutterfire configure for the customer app.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyChHovxhhvvrdYUyNJQBnw1UV9G_1O8_GA',
    appId: '1:881262711524:android:c522b63f25ecde019f52f1',
    messagingSenderId: '881262711524',
    projectId: 'cafe-73637',
    storageBucket: 'cafe-73637.firebasestorage.app',
  );

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
