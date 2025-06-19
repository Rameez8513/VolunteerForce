import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:ramiz_app/firebase_options.dart';
import 'package:ramiz_app/Authentication/login_page.dart';
import 'package:ramiz_app/Screens/Home/Home.dart'; // Import HomePage

void main() async {
  // 1. Ensure binding is initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase with error handling
  await _initializeFirebase();

  // 3. Run the app
  runApp(const MyApp());
}

Future<void> _initializeFirebase() async {
  try {
    // Check for existing Firebase apps
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
    } else {
      debugPrint('Firebase was already initialized');
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    rethrow; // Crash app if Firebase fails (recommended)
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // This StreamBuilder listens to changes in the authentication state
      // and decides whether to show LoginPage or HomePage.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loading indicator while checking auth state
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasData) {
            // User is logged in, navigate to HomePage
            return HomePage();
          } else {
            // User is not logged in, navigate to LoginPage
            return LoginPage();
          }
        },
      ),
    );
  }
}
