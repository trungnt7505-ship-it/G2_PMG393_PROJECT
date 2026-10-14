// File generated for Firebase configuration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Cấu hình [FirebaseOptions] dành cho các nền tảng (Web, Android, Windows).
/// Thay thế các giá trị bên dưới bằng thông tin dự án từ Firebase Console của bạn nếu cần:
/// https://console.firebase.google.com/
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
    apiKey: 'AIzaSyDemoCafeSystemKeyForPRM393Web123',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'cafe-system-prm393',
    authDomain: 'cafe-system-prm393.firebaseapp.com',
    storageBucket: 'cafe-system-prm393.appspot.com',
  );

  // Cấu hình Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemoCafeSystemKeyForPRM393Android',
    appId: '1:123456789012:android:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'cafe-system-prm393',
    storageBucket: 'cafe-system-prm393.appspot.com',
  );

  // Cấu hình Windows
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDemoCafeSystemKeyForPRM393Win123',
    appId: '1:123456789012:web:abcdef1234567890win',
    messagingSenderId: '123456789012',
    projectId: 'cafe-system-prm393',
    authDomain: 'cafe-system-prm393.firebaseapp.com',
    storageBucket: 'cafe-system-prm393.appspot.com',
  );
}
