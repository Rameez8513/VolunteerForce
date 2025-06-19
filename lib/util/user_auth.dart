import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserAuth {
  // Get Firebase Auth instance
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  // Get Firebase Realtime Database reference
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  static Future<bool> signupWithEmailPass({
    required String email,
    required String pass,
    required String name,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: pass);

      // Check if user was created successfully
      if (cred.user != null) {
        // AWAIT the saveUserData call here
        await saveUserData(cred.user!.uid, name, email);

        // Save user ID to shared preferences immediately after successful signup and data save
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', cred.user!.uid);
        await prefs.setString('userEmail', email); // Also save email

        return true; // Signup successful
      }
      return false; // User credential was null
    } on FirebaseAuthException catch (e) {
      print("Signup Firebase Auth Error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      print("Signup General Error: $e");
      return false;
    }
  }

  static Future<void> saveUserData(
      String uid, String name, String email) async {
    try {
      // Data is stored under 'users/{uid}/profile' to match common structures
      // and allow for more profile data later.
      // The path "users/$uid" is also fine if you prefer.
      DatabaseReference db = _databaseRef.child("allusers").child(uid);
      await db.set({
        "email": email,
        "name": name,
        "createdAt": ServerValue.timestamp, // Use ServerValue.timestamp for server-side time
      });
      print("User data saved to Realtime Database for UID: $uid"); // Debug print
    } catch (e) {
      print("Database write error for UID $uid: $e");
      // Consider rethrowing the error or returning a status if you want
      // signupWithEmailPass to handle it more specifically.
    }
  }

  static Future<bool> loginWithEmailPass({
    required String email,
    required String pass,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // Check if login was successful
      if (userCredential.user != null) {
        String uid = userCredential.user!.uid;
        String? userEmail = userCredential.user!.email;

        // Save user ID and email to shared preferences on login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', uid);
        await prefs.setString('userEmail', userEmail ?? email);

        return true; // Login successful
      }
      return false; // User credential was null
    } on FirebaseAuthException catch (e) {
      print("Login Firebase Auth Error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      print("Login General Error: $e");
      return false;
    }
  }

  // Method to get current user's name from Realtime Database
  static Future<String?> getUserName(String uid) async {
    try {
      // Fetch user data from Realtime Database using their UID
      DatabaseEvent event = await _databaseRef.child('users').child(uid).once();
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.exists) {
        Map<dynamic, dynamic>? userData = snapshot.value as Map<dynamic, dynamic>?;
        return userData?['name'] as String?;
      }
      return null; // User data not found
    } catch (e) {
      print('Error fetching user name from database for UID $uid: $e');
      return null;
    }
  }

  // Method to sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Clear shared preferences on sign out
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      await prefs.remove('userEmail');
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}
