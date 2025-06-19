import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ramiz_app/Parts/Post_job.dart'; // Ensure this path is correct
import 'package:ramiz_app/Screens/Home/job_detail.dart'; // Ensure this path is correct
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // For File class (even on web, it's part of the image_picker shim)
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Original lists to store all fetched jobs
  List<Map<String, dynamic>> _appliedJobs = [];
  List<Map<String, dynamic>> _postedJobs = [];
  List<Map<String, dynamic>> _completedJobs = [];

  // NEW: Filtered lists for displaying jobs based on search query
  List<Map<String, dynamic>> _filteredAppliedJobs = [];
  List<Map<String, dynamic>> _filteredPostedJobs = [];
  List<Map<String, dynamic>> _filteredCompletedJobs = [];

  bool _isLoadingAppliedJobs = true;
  bool _isLoadingPostedJobs = true;
  bool _isLoadingCompletedJobs = true;

  String _selectedTab = "Applied"; // Initial selected tab

  String _userName = 'Loading Name...';
  String _userEmail = 'Loading Email...';
  String? _userProfileImageUrl; // New variable to store profile image URL
  User? _currentUser;

  final ImagePicker _picker = ImagePicker(); // ImagePicker instance

  // NEW: TextEditingController for the search bar
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchUserData();
    // Start fetching and categorizing immediately on init
    _fetchAndCategorizeAppliedJobs(); // This will populate _appliedJobs and _completedJobs initially

    // NEW: Add listener to the search controller
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    // NEW: Dispose the search controller
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    if (_currentUser == null) {
      if (mounted) {
        setState(() {
          _userName = "Not Logged In";
          _userEmail = "No Email";
          _userProfileImageUrl = null; // No profile image if not logged in
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _userEmail = _currentUser!.email ?? 'No Email Provided';
      });
    }

    try {
      DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('allusers')
          .child(_currentUser!.uid);

      DataSnapshot nameSnapshot = await userRef.child('name').get();
      DataSnapshot profileImageSnapshot =
          await userRef.child('profileImageUrl').get();

      if (!mounted) return;

      if (nameSnapshot.exists && nameSnapshot.value != null) {
        setState(() {
          _userName = nameSnapshot.value.toString();
        });
      } else {
        setState(() {
          _userName = "Name not found";
        });
        print(
            "[_fetchUserData] User name not found in Realtime Database for UID: ${_currentUser!.uid}");
      }

      if (profileImageSnapshot.exists && profileImageSnapshot.value != null) {
        setState(() {
          _userProfileImageUrl = profileImageSnapshot.value.toString();
        });
      } else {
        setState(() {
          _userProfileImageUrl = null; // No profile image URL found
        });
        print(
            "[_fetchUserData] Profile image URL not found for UID: ${_currentUser!.uid}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userName = "Error fetching name";
        _userProfileImageUrl = null;
      });
      print(
          "[_fetchUserData] Error fetching user data from Realtime Database: $e");
    }
  }

  // New function to pick and upload image
  Future<void> _pickAndUploadImage() async {
    print('[_pickAndUploadImage] Function called.'); // Debug print
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please log in to upload a profile picture.')),
      );
      print(
          '[_pickAndUploadImage] User not logged in. Returning.'); // Debug print
      return;
    }

    try {
      print(
          '[_pickAndUploadImage] Attempting to pick image from gallery...'); // Debug print
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        print(
            '[_pickAndUploadImage] Image selected: ${image.path}'); // Debug print
        // Show a loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading profile picture...')),
        );

        File imageFile = File(
            image.path); // This works due to Flutter's web shim for dart:io
        String fileName = '${_currentUser!.uid}_profile_picture.jpg';
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child(fileName);

        print(
            '[_pickAndUploadImage] Starting upload to Firebase Storage...'); // Debug print
        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        print(
            '[_pickAndUploadImage] Image uploaded. Download URL: $downloadUrl'); // Debug print

        // Update Realtime Database with the new URL
        DatabaseReference userRef = FirebaseDatabase.instance
            .ref()
            .child('allusers')
            .child(_currentUser!.uid);
        print(
            '[_pickAndUploadImage] Updating Realtime Database at path: ${userRef.path} with URL.'); // Debug print
        await userRef.update({'profileImageUrl': downloadUrl});
        print(
            '[_pickAndUploadImage] Realtime Database updated successfully.'); // Debug print

        if (!mounted) return;
        setState(() {
          _userProfileImageUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile picture uploaded successfully!')),
        );
      } else {
        if (!mounted) return;
        print(
            '[_pickAndUploadImage] No image selected by user.'); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected.')),
        );
      }
    } catch (e) {
      print("[_pickAndUploadImage] Error picking or uploading image: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to upload profile picture: ${e.toString()}')),
      );
    }
  }

  // NEW: Method to filter jobs based on search query
  void _onSearchChanged() {
    final query = _searchController.text
        .toLowerCase()
        .trim(); // Get current text, lowercase, no leading/trailing spaces
    if (!mounted) return;

    setState(() {
      // Filter Applied Jobs
      if (query.isEmpty) {
        _filteredAppliedJobs = List.from(
            _appliedJobs); // If search is empty, show all applied jobs
      } else {
        _filteredAppliedJobs = _appliedJobs.where((job) {
          final title = job['title']?.toLowerCase() ??
              ''; // Get job title, handle null, make lowercase
          final location = job['location']?.toLowerCase() ?? '';
          final description = job['description']?.toLowerCase() ?? '';
          return title.contains(query) ||
              location.contains(query) ||
              description.contains(query);
        }).toList();
      }

      // Filter Posted Jobs
      if (query.isEmpty) {
        _filteredPostedJobs =
            List.from(_postedJobs); // If search is empty, show all posted jobs
      } else {
        _filteredPostedJobs = _postedJobs.where((job) {
          final title = job['title']?.toLowerCase() ?? '';
          final location = job['location']?.toLowerCase() ?? '';
          final description = job['description']?.toLowerCase() ?? '';
          return title.contains(query) ||
              location.contains(query) ||
              description.contains(query);
        }).toList();
      }

      // Filter Completed Jobs
      if (query.isEmpty) {
        _filteredCompletedJobs = List.from(
            _completedJobs); // If search is empty, show all completed jobs
      } else {
        _filteredCompletedJobs = _completedJobs.where((job) {
          final title = job['title']?.toLowerCase() ?? '';
          final location = job['location']?.toLowerCase() ?? '';
          final description = job['description']?.toLowerCase() ?? '';
          return title.contains(query) ||
              location.contains(query) ||
              description.contains(query);
        }).toList();
      }
    });
    print("DEBUG: ProfilePage - Search query: '$query'");
    print(
        "DEBUG: ProfilePage - Filtered Applied Jobs: ${_filteredAppliedJobs.length}");
    print(
        "DEBUG: ProfilePage - Filtered Posted Jobs: ${_filteredPostedJobs.length}");
    print(
        "DEBUG: ProfilePage - Filtered Completed Jobs: ${_filteredCompletedJobs.length}");
  }

  // REVISED _fetchAndCategorizeAppliedJobs with CORRECT DateFormat
  Future<void> _fetchAndCategorizeAppliedJobs() async {
    print('[_fetchAndCategorizeAppliedJobs] STARTING...');

    if (!mounted) return;

    setState(() {
      _isLoadingAppliedJobs = true;
      _isLoadingCompletedJobs = true;
      _appliedJobs = []; // Clear previous data
      _completedJobs = []; // Clear previous data
      _filteredAppliedJobs = []; // Clear filtered data too
      _filteredCompletedJobs = []; // Clear filtered data too
    });

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      print(
          '[_fetchAndCategorizeAppliedJobs] User not logged in. Cannot fetch applied jobs.');
      if (mounted) {
        setState(() {
          _isLoadingAppliedJobs = false;
          _isLoadingCompletedJobs = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please log in to see your applied jobs.')),
      );
      return;
    }

    final String currentUserUid = _currentUser!.uid;
    print('[_fetchAndCategorizeAppliedJobs] Current User UID: $currentUserUid');

    try {
      final userAppliedJobsRef =
          FirebaseDatabase.instance.ref('users/$currentUserUid/appliedJobs');
      final userCompletedJobsRef =
          FirebaseDatabase.instance.ref('users/$currentUserUid/completedJobs');
      final jobsDataRef = FirebaseDatabase.instance.ref('jobs/jobdata');

      // --- Step 1: Fetch all currently applied job IDs for the user ---
      final appliedIdsSnapshot = await userAppliedJobsRef.get();
      Set<String> appliedJobIdsInFirebase =
          {}; // Using Set for efficient lookups
      if (appliedIdsSnapshot.exists && appliedIdsSnapshot.value is Map) {
        (appliedIdsSnapshot.value as Map).forEach((key, value) {
          if (value == true && key is String) {
            appliedJobIdsInFirebase.add(key);
          }
        });
      }
      print(
          '[_fetchAndCategorizeAppliedJobs] Fetched Applied Job IDs in Firebase: ${appliedJobIdsInFirebase.length} items: $appliedJobIdsInFirebase');

      // --- Step 2: Fetch all currently completed job IDs for the user ---
      final completedIdsSnapshot = await userCompletedJobsRef.get();
      Set<String> completedJobIdsInFirebase =
          {}; // Using Set for efficient lookups
      if (completedIdsSnapshot.exists && completedIdsSnapshot.value is Map) {
        (completedIdsSnapshot.value as Map).forEach((key, value) {
          if (value == true && key is String) {
            completedJobIdsInFirebase.add(key);
          }
        });
      }
      print(
          '[_fetchAndCategorizeAppliedJobs] Fetched Completed Job IDs in Firebase: ${completedJobIdsInFirebase.length} items: $completedJobIdsInFirebase');

      // --- Step 3: Combine all unique job IDs to fetch full details efficiently ---
      // We only care about jobs the user has applied to or has completed
      Set<String> allRelevantJobIds = {};
      allRelevantJobIds.addAll(appliedJobIdsInFirebase);
      allRelevantJobIds.addAll(completedJobIdsInFirebase);
      print(
          '[_fetchAndCategorizeAppliedJobs] All Unique Relevant Job IDs: ${allRelevantJobIds.length} items: $allRelevantJobIds');

      List<Map<String, dynamic>> fetchedAppliedJobs = [];
      List<Map<String, dynamic>> fetchedCompletedJobs = [];

      // --- Step 4: Fetch full job details for all relevant jobs and categorize ---
      for (String jobId in allRelevantJobIds) {
        final jobSnapshot = await jobsDataRef.child(jobId).get();

        if (jobSnapshot.exists && jobSnapshot.value is Map) {
          final jobData = Map<String, dynamic>.from(jobSnapshot.value as Map);
          jobData['id'] = jobId; // Ensure the ID is part of the job data map

          // Provide robust default values
          jobData['imageUrl'] = jobData['imageUrl'] ??
              'assets/images/google_logo.png'; // Make sure this asset exists
          jobData['title'] = jobData['title'] ?? 'Job Title N/A';
          jobData['date'] = jobData['date'] ?? 'N/A';
          jobData['tillDate'] = jobData['last_date'] ?? 'N/A';
          jobData['description'] =
              jobData['description'] ?? 'No description provided.';
          jobData['requirements'] =
              jobData['requirements'] ?? 'No specific requirements listed.';
          jobData['location'] = jobData['location'] ?? 'Location not specified';

          String? lastDateStr = jobData['last_date'];
          print(
              '[_fetchAndCategorizeAppliedJobs] Processing job $jobId, title: ${jobData['title']}, raw last_date: "$lastDateStr"');

          bool isExpired = false;
          if (lastDateStr != null &&
              lastDateStr != 'N/A' &&
              lastDateStr.isNotEmpty) {
            try {
              // *** CRITICAL CORRECTION: DateFormat matches 'yyyy-M-d' from Firebase ***
              DateTime lastDate = DateFormat('yyyy-M-d').parse(lastDateStr);
              // Set time to end of day (23:59:59) for comparison to include the entire last date
              lastDate = DateTime(
                  lastDate.year, lastDate.month, lastDate.day, 23, 59, 59);

              print(
                  '[_fetchAndCategorizeAppliedJobs] Parsed lastDate for $jobId: $lastDate');
              print(
                  '[_fetchAndCategorizeAppliedJobs] Current DateTime (PKT assumed): ${DateTime.now()}');
              isExpired = lastDate.isBefore(DateTime.now());
              print(
                  '[_fetchAndCategorizeAppliedJobs] Job $jobId isExpired: $isExpired');
            } on FormatException catch (e) {
              print(
                  '[_fetchAndCategorizeAppliedJobs] WARNING: DateFormat failed for "$lastDateStr" for job $jobId. Error: $e');
              isExpired = false;
            } catch (e) {
              print(
                  '[_fetchAndCategorizeAppliedJobs] UNEXPECTED ERROR during date processing for job $jobId: $e');
              isExpired = false;
            }
          } else {
            print(
                '[_fetchAndCategorizeAppliedJobs] Job $jobId has no valid last_date. Assuming not expired.');
            isExpired = false; // No last_date means not expired by default
          }

          // Decide where to put the job in local lists and if Firebase needs updates
          if (isExpired) {
            fetchedCompletedJobs.add(jobData);
            // If it's expired and was in 'applied', move it in Firebase
            if (appliedJobIdsInFirebase.contains(jobId)) {
              print(
                  '[_fetchAndCategorizeAppliedJobs] Action: Moving $jobId from Applied to Completed in Firebase.');
              await userAppliedJobsRef.child(jobId).remove();
              await userCompletedJobsRef.child(jobId).set(true);
            }
          } else {
            // Not expired
            fetchedAppliedJobs.add(jobData);
            // If it's not expired but was in 'completed', move it back to applied (cleanup for miscategorized)
            if (completedJobIdsInFirebase.contains(jobId)) {
              print(
                  '[_fetchAndCategorizeAppliedJobs] Action: Correcting $jobId: Moving from Completed back to Applied in Firebase.');
              await userCompletedJobsRef.child(jobId).remove();
              await userAppliedJobsRef.child(jobId).set(true);
            }
          }
        } else {
          // Job details not found in 'jobs/jobdata' for this ID. Clean up user's records.
          print(
              '[_fetchAndCategorizeAppliedJobs] Job data not found or invalid for ID: $jobId in main "jobs/jobdata". Cleaning up user records.');
          if (appliedJobIdsInFirebase.contains(jobId)) {
            await userAppliedJobsRef.child(jobId).remove();
            print(
                '[_fetchAndCategorizeAppliedJobs] Removed $jobId from user\'s appliedJobs (no job data).');
          }
          if (completedJobIdsInFirebase.contains(jobId)) {
            await userCompletedJobsRef.child(jobId).remove();
            print(
                '[_fetchAndCategorizeAppliedJobs] Removed $jobId from user\'s completedJobs (no job data).');
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _appliedJobs = fetchedAppliedJobs;
        _completedJobs = fetchedCompletedJobs;
        // NEW: Initialize filtered lists with full data
        _filteredAppliedJobs = List.from(_appliedJobs);
        _filteredCompletedJobs = List.from(_completedJobs);
        _isLoadingAppliedJobs = false;
        _isLoadingCompletedJobs = false;
      });
      print(
          '[_fetchAndCategorizeAppliedJobs] FINISHED. Applied count: ${_appliedJobs.length}, Completed count: ${_completedJobs.length}');
      print('[_fetchAndCategorizeAppliedJobs] Displaying Applied Jobs:');
      _appliedJobs.forEach((job) => print(
          '   - ${job['title']} (ID: ${job['id']}, Last Date: ${job['tillDate']})'));
      print('[_fetchAndCategorizeAppliedJobs] Displaying Completed Jobs:');
      _completedJobs.forEach((job) => print(
          '   - ${job['title']} (ID: ${job['id']}, Last Date: ${job['tillDate']})'));
    } catch (e) {
      print('[_fetchAndCategorizeAppliedJobs] FATAL ERROR: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingAppliedJobs = false;
        _isLoadingCompletedJobs = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load jobs: ${e.toString()}')),
      );
    }
  }

  Future<void> _fetchPostedJobs() async {
    print('[_fetchPostedJobs] started...');

    if (!mounted) return;

    setState(() {
      _isLoadingPostedJobs = true;
      _postedJobs = [];
      _filteredPostedJobs = []; // Clear filtered data too
    });

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      print('[_fetchPostedJobs] User not logged in. Cannot fetch posted jobs.');
      if (mounted) {
        setState(() {
          _isLoadingPostedJobs = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to see your posted jobs.')),
      );
      return;
    }

    final String currentUserUid = _currentUser!.uid;
    print('[_fetchPostedJobs] Current User UID: $currentUserUid');

    try {
      final jobsRef = FirebaseDatabase.instance.ref('jobs').child('jobdata');
      print('[_fetchPostedJobs] Querying jobs from path: ${jobsRef.path}');

      final snapshot = await jobsRef
          .orderByChild('posted_by_uid')
          .equalTo(currentUserUid)
          .get();

      print('[_fetchPostedJobs] snapshot exists: ${snapshot.exists}');
      print('[_fetchPostedJobs] snapshot value: ${snapshot.value}');

      List<Map<String, dynamic>> fetchedJobs = [];
      if (snapshot.exists && snapshot.value is Map) {
        Map<dynamic, dynamic> jobsMap = snapshot.value as Map;
        jobsMap.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            final jobData = Map<String, dynamic>.from(value);
            jobData['id'] = key;

            // Robust default values
            jobData['imageUrl'] = jobData['imageUrl'] ??
                'assets/images/uet.png'; // Make sure this asset exists
            jobData['title'] = jobData['title'] ?? 'Job Title N/A';
            jobData['date'] = jobData['date'] ?? 'N/A';
            jobData['tillDate'] = jobData['last_date'] ?? 'N/A';
            jobData['description'] =
                jobData['description'] ?? 'No description provided.';
            jobData['requirements'] =
                jobData['requirements'] ?? 'No specific requirements listed.';
            jobData['location'] =
                jobData['location'] ?? 'Location not specified';

            fetchedJobs.add(jobData);
            print(
                '[_fetchPostedJobs] Added job: ${jobData['title']} with ID: $key');
          }
        });
      }

      if (!mounted) return;
      setState(() {
        _postedJobs = fetchedJobs;
        // NEW: Initialize filtered list with full data
        _filteredPostedJobs = List.from(_postedJobs);
        _isLoadingPostedJobs = false;
      });
      print(
          '[_fetchPostedJobs] State updated. Posted jobs count: ${_postedJobs.length}');
    } catch (e) {
      print('[_fetchPostedJobs] ERROR: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingPostedJobs = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load posted jobs: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Column(
          children: [
            // --- Top Profile Section with Dynamic Name and Email ---
            Container(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20, bottom: 20),
              color: Colors.indigo.shade900,
              child: Center(
                child: Column(
                  children: [
                    GestureDetector(
                        onTap:
                            _pickAndUploadImage, // Call the image picker function
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(
                            Icons
                                .account_circle, // Most realistic built-in option
                            size: 50, // Larger size for details
                            color: Colors.blueGrey,
                          ),
                        )),
                    const SizedBox(height: 10),
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _userEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- End Top Profile Section ---

            // --- Search Bar ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController, // CONNECT THE CONTROLLER HERE
                decoration: InputDecoration(
                  hintText: "Find your related jobs here",
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                ),
              ),
            ),
            // --- End Search Bar ---

            const SizedBox(height: 10),

            // --- Tab Bar Container ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TabButton(
                    text: "Applied",
                    isSelected: _selectedTab == "Applied",
                    onTap: () {
                      if (_selectedTab != "Applied") {
                        setState(() {
                          _selectedTab = "Applied";
                        });
                      }
                      _searchController
                          .clear(); // Clear search when changing tabs
                      _fetchAndCategorizeAppliedJobs(); // Always re-fetch when "Applied" is selected
                    },
                  ),
                  TabButton(
                    text: "Posted",
                    isSelected: _selectedTab == "Posted",
                    onTap: () {
                      if (_selectedTab != "Posted") {
                        setState(() {
                          _selectedTab = "Posted";
                        });
                      }
                      _searchController
                          .clear(); // Clear search when changing tabs
                      _fetchPostedJobs();
                    },
                  ),
                  TabButton(
                    text: "Completed",
                    isSelected: _selectedTab == "Completed",
                    onTap: () {
                      if (_selectedTab != "Completed") {
                        setState(() {
                          _selectedTab = "Completed";
                        });
                      }
                      _searchController
                          .clear(); // Clear search when changing tabs
                      // For simplicity, we assume _completedJobs is up-to-date from previous Applied tab load.
                      // If you want to force a refresh on "Completed" tab selection,
                      // uncomment the line below:
                      // _fetchAndCategorizeAppliedJobs(); // This fetches both applied and completed
                      // However, to ensure _filteredCompletedJobs is correct after clearing search:
                      _onSearchChanged(); // Re-run search filter for current tab
                    },
                  ),
                ],
              ),
            ),
            // --- End Tab Bar Container ---

            // --- Posts Section (Displays jobs based on selected tab) ---
            Expanded(
              child: Builder(
                builder: (BuildContext context) {
                  if (_selectedTab == "Applied") {
                    return _isLoadingAppliedJobs
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredAppliedJobs.isEmpty // Use filtered list
                            ? const Center(
                                child: Text(
                                    "No jobs applied for yet or matching your search."))
                            : ListView.builder(
                                padding: const EdgeInsets.all(10),
                                itemCount: _filteredAppliedJobs
                                    .length, // Use filtered list length
                                itemBuilder: (context, index) {
                                  final job = _filteredAppliedJobs[
                                      index]; // Use filtered list item
                                  return InfoCard(
                                    // Ensure InfoCard is defined or imported correctly
                                    imageUrl: job['imageUrl'],
                                    title: job['title'],
                                    date: job['date'],
                                    location: job['location'],
                                    tillDate: job['tillDate'],
                                    jobData: job,
                                    jobId: job['id'],
                                    suffixIcon: Icons.bookmark,
                                  );
                                },
                              );
                  } else if (_selectedTab == "Posted") {
                    return _isLoadingPostedJobs
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredPostedJobs.isEmpty // Use filtered list
                            ? const Center(
                                child: Text(
                                    "No jobs posted by you yet or matching your search."))
                            : ListView.builder(
                                padding: const EdgeInsets.all(10),
                                itemCount: _filteredPostedJobs
                                    .length, // Use filtered list length
                                itemBuilder: (context, index) {
                                  final job = _filteredPostedJobs[
                                      index]; // Use filtered list item
                                  return InfoCard(
                                    // Ensure InfoCard is defined or imported correctly
                                    imageUrl: job['imageUrl'],
                                    title: job['title'],
                                    date: job['date'],
                                    location: job['location'],
                                    tillDate: job['tillDate'],
                                    jobData: job,
                                    jobId: job['id'],
                                    suffixIcon: Icons.bookmark,
                                  );
                                },
                              );
                  } else {
                    // _selectedTab == "Completed"
                    return _isLoadingCompletedJobs
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredCompletedJobs.isEmpty // Use filtered list
                            ? const Center(
                                child: Text(
                                    "No completed jobs yet or matching your search."))
                            : ListView.builder(
                                padding: const EdgeInsets.all(10),
                                itemCount: _filteredCompletedJobs
                                    .length, // Use filtered list length
                                itemBuilder: (context, index) {
                                  final job = _filteredCompletedJobs[
                                      index]; // Use filtered list item
                                  return InfoCard(
                                    // Ensure InfoCard is defined or imported correctly
                                    imageUrl: job['imageUrl'],
                                    title: job['title'],
                                    date: job['date'],
                                    location: job['location'],
                                    tillDate: job['tillDate'],
                                    jobData: job,
                                    jobId: job['id'],
                                    suffixIcon: Icons.check_circle,
                                  );
                                },
                              );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const TabButton({
    Key? key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade900 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.indigo.shade900 : Colors.grey.shade400,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.indigo.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
