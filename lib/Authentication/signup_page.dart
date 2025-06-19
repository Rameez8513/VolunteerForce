import 'package:flutter/material.dart';
import 'package:ramiz_app/Authentication/login_page.dart';
import 'package:ramiz_app/util/user_auth.dart'; // Import your UserAuth file
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for Google Sign-In and UserCredential

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false; // State to manage loading indicator

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showPopup(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateAndSignUp() async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (name.isEmpty) {
      showPopup(context, "Validation Error", "Please enter your full name.");
      return;
    }

    // Email Validation
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+").hasMatch(email)) {
      showPopup(context, "Validation Error", "Please enter a valid email address.");
      return;
    }

    // Password Validation
    if (password.length < 8) {
      showPopup(context, "Validation Error", "Password is too short. It must be at least 8 characters long.");
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // Use the signupWithEmailPass method from UserAuth
      bool success = await UserAuth.signupWithEmailPass(
        email: email,
        pass: password,
        name: name, // Pass the name to UserAuth
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signup Successful!")),
        );
        Navigator.pushReplacement( // Use pushReplacement to prevent going back to signup
          context,
          MaterialPageRoute(builder: (context) => LoginPage()), // Removed const
        );
      } else {
        // UserAuth.signupWithEmailPass already prints errors,
        // but you can add more specific UI feedback here if needed.
        showPopup(context, "Signup Failed", "An error occurred during signup. Please try again.");
      }
    } catch (e) {
      // This catch block is for unexpected errors not handled by UserAuth
      showPopup(context, "Error", "An unexpected error occurred: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  // Function to sign up with Google
  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the Google sign-in flow
        setState(() { _isLoading = false; });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // IMPORTANT: Save user data into database using UserAuth.saveUserData
      // For Google Sign-In, displayName is usually available.
      // If displayName is null, you might prompt the user for a name later or use a default.
      String userName = googleUser.displayName ?? googleUser.email!.split('@')[0]; // Fallback name
      String userEmail = googleUser.email;

      await UserAuth.saveUserData(
        userCredential.user!.uid,
        userName,
        userEmail,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Signup Successful!")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()), // Removed const
      );
    } on FirebaseAuthException catch (e) {
      print("Google Signup Firebase Auth Error: $e");
      showPopup(context, "Google Signup Failed", "Firebase error: ${e.message}");
    } catch (e) {
      print("Google Signup General Error: $e");
      showPopup(context, "Google Signup Failed", "An unexpected error occurred: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 100), // Adjusted height for better spacing
              const Text(
                "Create an Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Register yourself as volunteer to continue starting activities",
                style: TextStyle(fontSize: 15, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 35),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  hintText: "abc@gmail.com",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator() // Show loading indicator
                  : ElevatedButton(
                      onPressed: _validateAndSignUp, // Call the validation and signup method
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade900,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("SIGN UP", style: TextStyle(color: Colors.white)),
                    ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _signUpWithGoogle, // Call the Google signup method
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // You might want to add a Google icon here
                    // Example: Image.asset('assets/google_logo.png', height: 24.0),
                    SizedBox(width: 10),
                    Text("SIGN UP WITH GOOGLE"),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement( // Use pushReplacement
                        context,
                        MaterialPageRoute(builder: (context) =>   LoginPage()),
                      );
                    },
                    child: const Text(
                      "Sign in",
                      style: TextStyle(color: Color(0xFFF57C00)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
