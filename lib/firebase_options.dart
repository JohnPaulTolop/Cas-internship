import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Only the Firebase Web app is configured. Register the Android/iOS apps '
      'in Firebase and run flutterfire configure before building for mobile.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyComIkIAq82g1WmjKhOZYoNFuXT_Bqf6Xs',
    appId: '1:177144288884:web:2f6af2d3e029a2c4072321',
    messagingSenderId: '177144288884',
    projectId: 'integratedschoolmanageme-8a7ef',
    authDomain: 'integratedschoolmanageme-8a7ef.firebaseapp.com',
    databaseURL:
        'https://integratedschoolmanageme-8a7ef-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'integratedschoolmanageme-8a7ef.firebasestorage.app',
    measurementId: 'G-ZVY3NDECEP',
  );
}
