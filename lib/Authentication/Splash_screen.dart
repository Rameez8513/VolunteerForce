import 'package:flutter/material.dart';
import 'package:ramiz_app/Authentication/login_page.dart'; // Import Login Page

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 300), // Adjust top spacing

            SizedBox(height: 30), // Spacing before image

            // Image from assets (Make sure to add this image in assets folder)
            Center(
              child: Image.asset(
                'assets/images/splas.png', // Replace with actual image file
                height: 300, // Adjust height as per design
              ),
            ),

            SizedBox(height: 30), // Space between image and text

            // Main Heading
            Text(
              "Go forward to work as",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              "Volunteer",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF57C00), // Yellow color
              ),
            ),
            SizedBox(height: 10),

            // Subtext
            Text(
              "Explore all the most exciting volunteer roles based on your interest and study major.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),

            // Spacer(), // Pushes button to bottom
            SizedBox(height: 10),
            // Forward Arrow Button
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon:
                    Icon(Icons.arrow_forward, size: 30, color: Colors.black87),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
              ),
            ),
            SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }
}
