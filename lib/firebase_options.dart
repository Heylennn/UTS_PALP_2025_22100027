import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDg0WPXf65O2DNuTqvdq7KLG9rdlc9PB3Q', 
      appId: '1:234429057174:android:a2482a2d1768f4f4489ab7', 
      messagingSenderId: '234429057174', 
      projectId: 'project-latihan-penjualan', 
      storageBucket: 'project-latihan-penjualan.firebasestorage.app', 
    );
  }
}