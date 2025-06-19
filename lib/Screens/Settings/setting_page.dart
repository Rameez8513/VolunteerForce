import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // ADDED: Import Firebase Database
import 'package:ramiz_app/Parts/Navigation_bar.dart';
import 'package:ramiz_app/Parts/setting_tiles.dart';
import 'package:ramiz_app/Parts/Top_navigation.dart';
import 'package:ramiz_app/Screens/Saved/saved_page.dart';
import 'package:ramiz_app/Screens/Profile/profile_page.dart';
import 'package:ramiz_app/Screens/Add_Job/add_job.dart';
import 'package:ramiz_app/Screens/Home/Home.dart';
import 'package:ramiz_app/Authentication/forgetpassword.dart';
import 'package:ramiz_app/Authentication/login_page.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkModeEnabled = false;
  User? _currentUser;
  String _userName = "Loading Name..."; // State for user's name from DB

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchUserName(); // Call the method to fetch user name
  }

  // ADDED: Function to fetch user name from Realtime Database
  Future<void> _fetchUserName() async {
    if (_currentUser == null) {
      setState(() {
        _userName = "Not Logged In";
      });
      return;
    }

    try {
      // Assuming your database structure is something like:
      // users:
      //   <uid>:
      //     name: "User's Name"
      //     email: "user@example.com"
      //     ...
      DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('allusers')
          .child(_currentUser!.uid);

      DataSnapshot snapshot =
          await userRef.child('name').get(); // Fetch only the 'name' field

      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _userName = snapshot.value.toString();
        });
      } else {
        setState(() {
          _userName = "Name not found";
        });
        print(
            "User name not found in Realtime Database for UID: ${_currentUser!.uid}");
      }
    } catch (e) {
      setState(() {
        _userName = "Error fetching name";
      });
      print("Error fetching user name from Realtime Database: $e");
    }
  }

  // ADDED: Function to show Help dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Help"),
          content: Text(
              "Welcome to the Help section! Here you can find answers to common questions and guides on how to use the app. If you need further assistance, please use the 'Report Problem' feature."),
          actions: <Widget>[
            TextButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // ADDED: Function to show Policies dialog
  void _showPoliciesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Policies"),
          content: SingleChildScrollView(
            child: Text(
              "VolunteerForce Policies:\n\n"
              "1. Data Privacy: We are committed to protecting your personal data. All information collected is used solely for the purpose of facilitating volunteer activities and will not be shared with third parties without your explicit consent.\n\n"
              "2. Code of Conduct: Users are expected to maintain a respectful and professional demeanor. Any form of harassment, discrimination, or inappropriate behavior will result in immediate account suspension.\n\n"
              "3. Content Guidelines: All content posted on the platform must be relevant to volunteer work and adhere to legal and ethical standards. Prohibited content includes spam, fraudulent information, and illegal activities.\n\n"
              "4. Reporting Misconduct: If you encounter any policy violations or suspicious activities, please use the 'Report Problem' feature to notify our team. We will investigate all reports promptly.\n\n"
              "5. Account Responsibility: You are responsible for maintaining the confidentiality of your account credentials. Report any unauthorized access immediately.\n\n"
              "By using VolunteerForce, you agree to abide by these policies.",
              textAlign: TextAlign.justify,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // ADDED: Function to show Report Problem dialog
  void _showReportProblemDialog() {
    TextEditingController _problemController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Report a Problem"),
          content: TextField(
            controller: _problemController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "Describe the problem you are facing...",
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text("Submit"),
              onPressed: () {
                String problemDescription = _problemController.text;
                if (problemDescription.isNotEmpty) {
                  print("Problem Reported: $problemDescription");
                  // In a real app, you would send this to a backend service
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Problem reported successfully!")));
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Please enter a description.")));
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        bottomNavigationBar: BottomNavBar(
            selectedIndex: 3,
            onTap: (index) {
              if (index == 1) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => SavedJobsPage()));
              } else if (index == 2) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => AddJobPage()));
              } else if (index == 4) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => ProfilePage()));
              } else if (index == 0) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => HomePage()));
              }
            }),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                TopContainer(title: "Settings"),
                SizedBox(height: 20),

                // Centered Profile Image & Email
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(
                    Icons.account_circle, // Most realistic built-in option
                    size: 50, // Larger size for details
                    color: Colors.blueGrey,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  _userName, // Display the fetched user name
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _currentUser?.email ?? "No Email",
                  style: TextStyle(color: Colors.grey),
                ),

                SizedBox(height: 30),

                // General Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 8),
                    child: Text("General",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade300, blurRadius: 5)
                    ],
                  ),
                  child: Column(
                    children: [
                      SettingsTile(
                        icon: Icons.lock,
                        title: "Change Password",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ForgetPasswordPage()),
                          );
                        },
                      ),
                      Divider(),
                      SwitchListTile(
                        title: Text("Dark Mode"),
                        value: _darkModeEnabled,
                        onChanged: (value) {
                          setState(() {
                            _darkModeEnabled = value;
                            // TODO: Implement actual theme change logic here.
                            // This would typically involve using a ThemeProvider or changing the MaterialApp's theme.
                            print("Dark Mode: $_darkModeEnabled");
                          });
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Help & Legal Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 8),
                    child: Text("Help & Legal",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade300, blurRadius: 5)
                    ],
                  ),
                  child: Column(
                    children: [
                      SettingsTile(
                          icon: Icons.help_outline,
                          title: "Help",
                          onTap: _showHelpDialog), // MODIFIED
                      Divider(),
                      SettingsTile(
                          icon: Icons.policy,
                          title: "Policies",
                          onTap: _showPoliciesDialog), // MODIFIED
                      Divider(),
                      SettingsTile(
                          icon: Icons.report_problem,
                          title: "Report Problem",
                          onTap: _showReportProblemDialog), // MODIFIED
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Logout Button
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade300, blurRadius: 5)
                    ],
                  ),
                  child: SettingsTile(
                    icon: Icons.logout,
                    title: "Logout",
                    onTap: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => LoginPage()),
                          (Route<dynamic> route) => false,
                        );
                      } catch (e) {
                        print("Error during logout: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text("Logout failed. Please try again.")),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
