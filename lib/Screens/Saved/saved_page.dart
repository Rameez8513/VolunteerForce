import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Import Firebase Auth
import 'package:ramiz_app/Parts/Navigation_bar.dart';
import 'package:ramiz_app/Parts/Post_job.dart'; // Assuming InfoCard is here based on your description
import 'package:ramiz_app/Parts/Top_navigation.dart';
import 'package:ramiz_app/Screens/Profile/profile_page.dart';
import 'package:ramiz_app/Screens/Settings/setting_page.dart';
import 'package:ramiz_app/Screens/Add_Job/add_job.dart';
import 'package:ramiz_app/Screens/Home/Home.dart';

class SavedJobsPage extends StatefulWidget {
  @override
  _SavedJobsPageState createState() => _SavedJobsPageState();
}

class _SavedJobsPageState extends State<SavedJobsPage> {
  // NEW: Get the current user from Firebase Auth
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Database reference for saved jobs (initialized in initState based on _currentUser)
  late DatabaseReference _savedJobsRef;

  List<Map<String, dynamic>> _savedJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize _savedJobsRef only if a user is logged in
    if (_currentUser != null) {
      _savedJobsRef = FirebaseDatabase.instance.ref('users/${_currentUser!.uid}/savedJobs');
      _fetchSavedJobs();
    } else {
      // If no user is logged in, set loading to false and show no jobs
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in to view saved jobs!")),
        );
      });
    }
  }

  Future<void> _fetchSavedJobs() async {
    setState(() {
      _isLoading = true;
    });

    // Ensure user is logged in before fetching
    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
        _savedJobs = [];
      });
      return;
    }

    try {
      // Listen for changes in the saved jobs for the current user
      _savedJobsRef.onValue.listen((event) {
        final DataSnapshot snapshot = event.snapshot;
        final dynamic savedJobsRaw = snapshot.value;

        if (savedJobsRaw != null && savedJobsRaw is Map) {
          final Map<String, dynamic> savedJobsMap = Map<String, dynamic>.from(savedJobsRaw);
          List<Map<String, dynamic>> fetchedJobs = [];

          // Iterate through the saved jobs and add them to the list
          savedJobsMap.forEach((jobId, jobData) {
            // Check if jobData is a Map, as we are now saving the whole jobData
            if (jobData is Map) {
              fetchedJobs.add(
                Map<String, dynamic>.from({
                  'jobId': jobId, // Include the jobId
                  ...jobData,    // Spread the actual job details saved from InfoCard
                }),
              );
            }
          });

          setState(() {
            _savedJobs = fetchedJobs;
            _isLoading = false;
          });
        } else {
          // No saved jobs or unexpected format
          setState(() {
            _savedJobs = [];
            _isLoading = false;
          });
        }
      }, onError: (error) {
        print("Error listening to saved jobs: $error");
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load saved jobs: ${error.toString()}')),
        );
      });

    } catch (e) {
      print("Error fetching saved jobs: $e");
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load saved jobs: ${e.toString()}')),
      );
    }
  }


  // Function to remove a job from saved directly from this page
  void _removeJobFromSaved(String jobId) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to unsave jobs!")),
      );
      return;
    }
    try {
      await _savedJobsRef.child(jobId).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job unsaved!')),
      );
      // The `onValue` listener will automatically update the list, no need to call _fetchSavedJobs()
    } catch (e) {
      print("Error removing job from saved: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unsave job: ${e.toString()}')),
      );
    }
  }

  // NEW: Function to delete all saved jobs for the current user
  Future<void> _deleteAllSavedJobs() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to delete saved jobs!")),
      );
      return;
    }
    try {
      setState(() {
        _isLoading = true; // Show loading indicator during deletion
      });
      await _savedJobsRef.remove(); // Deletes the 'savedJobs' node for the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All saved jobs removed!')),
      );
      // The `onValue` listener will automatically update the list to empty
    } catch (e) {
      print("Error deleting all saved jobs: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete all saved jobs: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Stop loading regardless of success or failure
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        bottomNavigationBar: BottomNavBar(
          selectedIndex: 1, // Assuming SavedJobsPage is the second item (index 1)
          onTap: (index) {
            if (index == 0) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
            } else if (index == 2) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AddJobPage()));
            } else if (index == 3) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage()));
            } else if (index == 4) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()));
            }
          },
        ),
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const TopContainer(title: "Saved Activities"), // Added const

            // Delete All Button
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 10), // Added const
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _savedJobs.isEmpty ? null : _deleteAllSavedJobs, // Disable if no saved jobs
                  child: Text(
                    "Delete all",
                    style: TextStyle(
                      color: _savedJobs.isEmpty ? Colors.grey : Colors.red, // Grey out if no jobs
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator()) // Added const
                  : _savedJobs.isEmpty
                      ? const Center(child: Text("No saved jobs found.")) // Added const
                      : RefreshIndicator(
                          onRefresh: _fetchSavedJobs,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16), // Added const
                            itemCount: _savedJobs.length,
                            itemBuilder: (context, index) {
                              final job = _savedJobs[index];
                              return InfoCard(
                                imageUrl: job['imageUrl'] ?? 'assets/images/default.png',
                                title: job['title'] ?? 'No title',
                                date: job['date'] ?? 'No date',
                                location: job['location'] ?? 'No location',
                                tillDate: job['last_date'] ?? 'No end date', // Assuming 'last_date' in your Firebase
                                suffixIcon: Icons.bookmark, // Always show bookmark as it's saved
                                jobData: job, // Pass the entire job map
                                jobId: job['jobId'], // Pass the retrieved jobId
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}