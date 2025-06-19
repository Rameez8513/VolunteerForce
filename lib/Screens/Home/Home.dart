import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:ramiz_app/util/user_auth.dart'; // Import your UserAuth file
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth for signOut (if UserAuth doesn't handle all)

import 'package:ramiz_app/Parts/Job_type.dart'; // Contains CategoryCard
import 'package:ramiz_app/Parts/Post_job.dart'; // Contains InfoCard
import 'package:ramiz_app/Parts/Navigation_bar.dart';
import 'package:ramiz_app/Screens/Saved/saved_page.dart';
import 'package:ramiz_app/Screens/Profile/profile_page.dart';
import 'package:ramiz_app/Screens/Settings/setting_page.dart';
import 'package:ramiz_app/Screens/Add_Job/add_job.dart';
import 'package:ramiz_app/Authentication/login_page.dart'; // Import LoginPage for logout navigation
import 'dart:math'; // Import for the min function

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = 'there'; // Default name while loading or if not found
  String? _userEmail; // To display email if needed, or for debugging
  String? _currentUserId; // To store the fetched UID

  // NEW: Search functionality variables
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allJobs =
      []; // Stores all jobs fetched from Firebase
  List<Map<String, dynamic>> _displayedJobs =
      []; // Stores jobs currently shown (filtered or unfiltered)
  bool _isLoadingJobs = true; // Loading state for job posts

  // NEW: Map to store dynamic job counts per category
  Map<String, int> _categoryJobCounts = {
    'Animal Welfare': 0,
    'Volunteering': 0,
    'Healthcare': 0,
    'Education Sector': 0,
    'Food': 0,
    'Environment': 0,
    'Community Support': 0,
    'Disaster Relief': 0,
    'Arts & Culture': 0,
    'Sports & Recreation': 0, // Ensure all categories are initialized
  };

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Call method to load user data when the widget initializes
    _fetchCategoryJobCounts(); // Fetch job counts on init
    _fetchAllJobs(); // Fetch all jobs for the search functionality
    _searchController
        .addListener(_onSearchChanged); // Listen for search input changes
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    print("DEBUG: HomePage - _loadUserData called.");
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId'); // Retrieve the stored UID
    final userEmail = prefs.getString('userEmail'); // Retrieve the stored email

    print(
        "DEBUG: HomePage - Retrieved from SharedPreferences - UID: $userId, Email: $userEmail");

    if (userId != null) {
      String? fetchedName = await UserAuth.getUserName(userId);
      if (mounted) {
        setState(() {
          _userName = fetchedName ??
              'User'; // Update the name, default to 'User' if null
          _currentUserId = userId;
          _userEmail = userEmail; // Set the email for display
        });
        print("DEBUG: HomePage - Updated _userName to: $_userName");
      }
    } else {
      if (mounted) {
        setState(() {
          _userName = 'Guest'; // Fallback for no logged-in user
          _userEmail = null; // Clear email if no user ID
        });
        print(
            "DEBUG: HomePage - No UID found in SharedPreferences. Displaying 'Guest'.");
      }
    }
  }

  // NEW METHOD: Fetches job counts for each category
  Future<void> _fetchCategoryJobCounts() async {
    try {
      final DatabaseEvent event =
          await FirebaseDatabase.instance.ref('jobs/jobdata').once();
      final DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null && snapshot.value is Map) {
        final Map<dynamic, dynamic> jobsData =
            snapshot.value as Map<dynamic, dynamic>;
        Map<String, int> tempCounts =
            Map.from(_categoryJobCounts); // Create a mutable copy

        // Reset counts before recounting
        tempCounts.updateAll((key, value) => 0);

        jobsData.forEach((jobId, jobValue) {
          final job = Map<String, dynamic>.from(jobValue);
          final category = job['category'] as String?;
          if (category != null && tempCounts.containsKey(category)) {
            tempCounts[category] = (tempCounts[category] ?? 0) + 1;
          }
        });

        if (mounted) {
          setState(() {
            _categoryJobCounts = tempCounts;
          });
          print("DEBUG: HomePage - Category Job Counts: $_categoryJobCounts");
        }
      } else {
        print("DEBUG: HomePage - No job data found for category counting.");
      }
    } catch (e) {
      print("Error fetching category job counts: $e");
    }
  }

  // NEW METHOD: Fetches ALL job posts for search and display
  Future<void> _fetchAllJobs() async {
    if (!mounted) return;
    setState(() {
      _isLoadingJobs = true;
    });

    try {
      final DatabaseEvent event =
          await FirebaseDatabase.instance.ref('jobs/jobdata').once();
      final DataSnapshot snapshot = event.snapshot;

      List<Map<String, dynamic>> fetchedJobs = [];
      if (snapshot.value != null && snapshot.value is Map) {
        final Map<dynamic, dynamic> jobsData =
            snapshot.value as Map<dynamic, dynamic>;

        // Convert Map to a List of entries, sort by 'posted_on' (most recent first)
        final List<MapEntry<dynamic, dynamic>> sortedEntries =
            jobsData.entries.toList()
              ..sort((a, b) {
                final String dateA = (a.value as Map)['posted_on'] ?? '';
                final String dateB = (b.value as Map)['posted_on'] ?? '';
                // Using a simple string comparison for dates, assuming "yyyy-MM-dd" format.
                // For robust date comparison, parse to DateTime.
                return dateB
                    .compareTo(dateA); // Descending order (most recent first)
              });

        for (var entry in sortedEntries) {
          final jobId = entry.key; // Get the unique job ID (Firebase key)
          final job = Map<String, dynamic>.from(entry.value);

          // Add robust default values
          job['id'] = jobId; // Ensure ID is part of the job map
          job['imageUrl'] = job['imageUrl'] ?? 'assets/images/uet.png';
          job['title'] = job['title'] ?? 'No title';
          job['date'] = job['date'] ?? 'No date';
          job['location'] = job['location'] ?? 'No location';
          job['tillDate'] = job['last_date'] ?? 'No end date';
          job['description'] = job['description'] ?? 'No description provided.';
          job['requirements'] =
              job['requirements'] ?? 'No requirements listed.';
          job['posted_by_uid'] = job['posted_by_uid'] ??
              ''; // Ensure this is present for filtering if needed

          fetchedJobs.add(job);
        }
      }

      if (mounted) {
        setState(() {
          _allJobs = fetchedJobs; // Store all jobs
          _displayedJobs = List.from(_allJobs); // Initially, display all jobs
          _isLoadingJobs = false;
        });
      }
      print("DEBUG: HomePage - Fetched ${_allJobs.length} jobs in total.");
    } catch (e) {
      print("Error fetching all jobs: $e");
      if (mounted) {
        setState(() {
          _isLoadingJobs = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load job posts: ${e.toString()}')),
        );
      }
    }
  }

  // NEW METHOD: Filters _allJobs based on search query and updates _displayedJobs
  void _onSearchChanged() {
    final query = _searchController.text
        .toLowerCase()
        .trim(); // Get current text, lowercase, no leading/trailing spaces
    if (mounted) {
      setState(() {
        if (query.isEmpty) {
          _displayedJobs =
              List.from(_allJobs); // If search is empty, show all jobs
        } else {
          _displayedJobs = _allJobs.where((job) {
            final title = job['title']?.toLowerCase() ??
                ''; // Get job title, handle null, make lowercase
            return title.contains(
                query); // Check if job title contains the search query
          }).toList();
        }
        print(
            "DEBUG: HomePage - Search query: '$query', Displaying ${_displayedJobs.length} jobs.");
      });
    }
  }

  Future<void> _logout() async {
    await UserAuth.signOut(); // Call the signOut method from UserAuth
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()), // Added const
        (Route<dynamic> route) => false, // Remove all routes below
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.indigo.shade900,
      ),
      child: Scaffold(
        bottomNavigationBar: BottomNavBar(
          selectedIndex: 0,
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SavedJobsPage())); // Added const
            } else if (index == 2) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddJobPage())); // Added const
            } else if (index == 3) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SettingsPage())); // Added const
            } else if (index == 4) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ProfilePage())); // Added const
            }
          },
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Top Container with dynamic name and search bar
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: 40,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade900,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(
                              Icons
                                  .account_circle, // Most realistic built-in option
                              size: 50, // Larger size for details
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hi, Welcome", // Now dynamically displays the user's name
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _userEmail ?? "Find your volunteer work here!",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon:
                                const Icon(Icons.logout, color: Colors.orange),
                            onPressed: _logout,
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller:
                                  _searchController, // CONNECT THE CONTROLLER HERE
                              decoration: InputDecoration(
                                hintText: "Enter Job title here",
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Categories section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              CategoryCard(
                                icon: Icons.pets,
                                title: "Animal Welfares",
                                jobCount:
                                    _categoryJobCounts['Animal Welfare'] ?? 0,
                                categoryName: "Animal Welfare",
                              ),
                              CategoryCard(
                                icon: Icons.volunteer_activism,
                                title: "Volunteers",
                                jobCount:
                                    _categoryJobCounts['Volunteering'] ?? 0,
                                categoryName: "Volunteering",
                              ),
                              CategoryCard(
                                icon: Icons.people,
                                title: "Community Support",
                                jobCount:
                                    _categoryJobCounts['Community Support'] ??
                                        0,
                                categoryName: "Community Support",
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              CategoryCard(
                                icon: Icons.medical_services,
                                title: "Healthcare Sector",
                                jobCount: _categoryJobCounts['Healthcare'] ?? 0,
                                categoryName: "Healthcare",
                              ),
                              CategoryCard(
                                icon: Icons.school,
                                title: "Education Sector",
                                jobCount:
                                    _categoryJobCounts['Education Sector'] ?? 0,
                                categoryName: "Education Sector",
                              ),
                              CategoryCard(
                                icon: Icons.volunteer_activism,
                                title: "Disaster Relief",
                                jobCount:
                                    _categoryJobCounts['Disaster Relief'] ?? 0,
                                categoryName: "Disaster Relief",
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              CategoryCard(
                                icon: Icons.food_bank,
                                title: "Food Support",
                                jobCount: _categoryJobCounts['Food'] ?? 0,
                                categoryName: "Food",
                              ),
                              CategoryCard(
                                icon: Icons.eco,
                                title: "Environment Sector",
                                jobCount:
                                    _categoryJobCounts['Environment'] ?? 0,
                                categoryName: "Environment",
                              ),
                              CategoryCard(
                                icon: Icons.palette,
                                title: "Arts & Culture",
                                jobCount:
                                    _categoryJobCounts['Arts & Culture'] ?? 0,
                                categoryName: "Arts & Culture",
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // Title for Job Posts / Search Results
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      "Job Posts", // Changed title to be more generic for search
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Firebase Posts (now driven by _displayedJobs and controlled by _isLoadingJobs)
                _isLoadingJobs
                    ? const Center(child: CircularProgressIndicator())
                    : _displayedJobs.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                  "No job posts found matching your search.",
                                  textAlign: TextAlign.center),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(10),
                            // <<< --- THIS IS THE CHANGE --- >>>
                            itemCount: min(_displayedJobs.length,
                                3), // Limit to a maximum of 3 posts
                            // <<< --- END CHANGE --- >>>
                            itemBuilder: (context, index) {
                              final job = _displayedJobs[index];
                              return InfoCard(
                                imageUrl:
                                    job['imageUrl'] ?? 'assets/images/uet.png',
                                title: job['title'] ?? 'No title',
                                date: job['date'] ?? 'No date',
                                location: job['location'] ?? 'No location',
                                tillDate: job['tillDate'] ?? 'No end date',
                                suffixIcon: Icons.bookmark,
                                jobData: job,
                                jobId: job['id'], // Ensure job ID is passed
                              );
                            },
                          ),
                // Add a small bottom padding if needed, especially if the last InfoCard touches the bottom nav bar
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
