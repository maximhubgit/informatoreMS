// File generato da FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Default [FirebaseOptions] per questa app.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions non sono definite per questa piattaforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBwvRJr4rDRrfBru-G2YsuF-Uq2ZI5NXuw',
    appId: '1:325738421283:android:1bd57ba071f656c0706596',
    messagingSenderId: '325738421283',
    projectId: 'informatorems-784a1',
    storageBucket: 'informatorems-784a1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBwvRJr4rDRrfBru-G2YsuF-Uq2ZI5NXuw',
    appId: '1:325738421283:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '325738421283',
    projectId: 'informatorems-784a1',
    storageBucket: 'informatorems-784a1.firebasestorage.app',
    iosBundleId: 'com.informatorems.informatoreMS',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBcwu2kN6FaxaNW61IqZY7ayPzAZ1rT6wk',
    appId: '1:325738421283:web:eec8b7b2712f287a706596',
    messagingSenderId: '325738421283',
    projectId: 'informatorems-784a1',
    authDomain: 'informatorems-784a1.firebaseapp.com',
    storageBucket: 'informatorems-784a1.firebasestorage.app',
  );
}
