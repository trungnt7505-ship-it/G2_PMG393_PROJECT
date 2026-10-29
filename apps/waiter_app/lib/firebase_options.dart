// File generated for Firebase configuration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Cấu hình [FirebaseOptions] dành cho các nền tảng (Web, Android, Windows).
/// Phục vụ kết nối ứng dụng Phục vụ (Waiter App) đến dự án Firebase cafe-73637.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  // Cấu hình Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDC5m684x2DNEZRuniQcQmkP4Oo5K9SHzY',
    appId: '1:881262711524:web:8dcdb9bf625587859f52f1',
    messagingSenderId: '881262711524',
    projectId: 'cafe-73637',
    authDomain: 'cafe-73637.firebaseapp.com',
    storageBucket: 'cafe-73637.firebasestorage.app',
  );

  // Cấu hình Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyChHovxhhvvrdYUyNJQBnw1UV9G_1O8_GA',
    appId: '1:881262711524:android:c651fe03c0af3ba09f52f1',
    messagingSenderId: '881262711524',
    projectId: 'cafe-73637',
    storageBucket: 'cafe-73637.firebasestorage.app',
  );

  // Cấu hình Windows
  static const FirebaseOptions windows = web;
}
