import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Replace these with your Firebase configuration values
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCb4BZXx_-JZkbRuR1_Mti9GuUlbVzFJp4",
    authDomain: "e-votex-app.firebaseapp.com",
    projectId: "e-votex-app",
    storageBucket: "e-votex-app.firebasestorage.app",
    messagingSenderId: "63037506767",
    appId: "1:63037506767:web:1d46249497c48b9e06e3ba",
    measurementId: "G-VRH3F2283L"
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBWjYsyq8CZ6fn_ZwnHxdepchFHiI1ttOE',
    appId: '1:63037506767:android:95d7cf22334fda6906e3ba',
    messagingSenderId: '63037506767',
    projectId: 'e-votex-app',
    storageBucket: 'e-votex-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR-IOS-API-KEY',
    appId: 'YOUR-IOS-APP-ID',
    messagingSenderId: 'YOUR-SENDER-ID',
    projectId: 'YOUR-PROJECT-ID',
    storageBucket: 'YOUR-STORAGE-BUCKET',
    iosClientId: 'YOUR-IOS-CLIENT-ID',
    iosBundleId: 'YOUR-IOS-BUNDLE-ID',
  );
}
