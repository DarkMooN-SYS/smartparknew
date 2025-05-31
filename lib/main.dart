import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_parking_system/components/login/login_main.dart';
import 'package:smart_parking_system/components/splashscreen/splash_screen.dart';
import 'package:smart_parking_system/components/notifications/notificationfunction.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // You can add logic here to handle the background message
}

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  print(dotenv.env['API_KEY']);
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  //dotenv.env['API_KEY']!
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['API_KEY']!,
        appId: "1:419907757847:android:e30aba44abcf584fe0b952",
        messagingSenderId: "419907757847",
        projectId: "parkme-246a0",
        storageBucket: "parkme-246a0.firebasestorage.app",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Get a reference to the storage service

  // final FirebaseStorage storage = FirebaseStorage.instanceFor(bucket: 'gs://parkme-c2508.appspot.com');
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FCMService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Parking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF35344A),
      ),
      home: const SplashScreen(
        child: LoginMainPage(),
      ),
    );
  }
}

// web config

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:smart_parking_system/webApp/components/splash.dart';

// class DefaultFirebaseOptions {
//   static FirebaseOptions get currentPlatform {
//     if (kIsWeb) {
//       return web;
//     }
//     throw UnsupportedError(
//       'DefaultFirebaseOptions are not supported for this platform.',
//     );
//   }

//   static FirebaseOptions web = const FirebaseOptions(
//       apiKey: "AIzaSyCJ-oWJdpQk4K-EtRhZwLrgeG6ds7OnY5E",
//       authDomain: "parkme-246a0.firebaseapp.com",
//       projectId: "parkme-246a0",
//       storageBucket: "parkme-246a0.firebasestorage.app",
//       messagingSenderId: "419907757847",
//       appId: "1:419907757847:web:6d248b164d20e029e0b952",
//       measurementId: "G-C9KY9G41BN");
//   }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Бүртгүүлэх & Нэвтрэх',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: const Splash(),
//     );
//   }
// }
