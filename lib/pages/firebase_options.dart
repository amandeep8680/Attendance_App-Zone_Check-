
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBTWCscncreEUZa2B2i8o1mE_zz0BONYFk',
    appId: '1:1097316044005:android:ac9d8aab6186f0ebf0180c',
    messagingSenderId: '1097316044005',
    projectId: 'zone-check-be677',
    databaseURL: 'https://zone-check-be677-default-rtdb.firebaseio.com',
    storageBucket: 'zone-check-be677.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyArdOB3XCL-3eNItZqLISJNAupJ4Zaj7zc',
    appId: '1:1097316044005:ios:c0683efd96d25194f0180c',
    messagingSenderId: '1097316044005',
    projectId: 'zone-check-be677',
    databaseURL: 'https://zone-check-be677-default-rtdb.firebaseio.com',
    storageBucket: 'zone-check-be677.firebasestorage.app',
    iosBundleId: 'com.example.attendanceAap',
  );

}