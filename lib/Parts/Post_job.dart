import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Database
import 'package:ramiz_app/Screens/Home/Job_detail.dart'; // Ensure this import is correct
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Import Firebase Auth

class InfoCard extends StatefulWidget { // Changed to StatefulWidget
  final String? imageUrl;
  final String title;
  final String date;
  final String location;
  final String tillDate;
  // suffixIcon is no longer directly used for the icon, as it's now dynamic based on saved status
  final Map<String, dynamic> jobData;
  final String jobId; // New: This is crucial for identifying the job in Firebase

  const InfoCard({
    Key? key,
    this.imageUrl,
    required this.title,
    required this.date,
    required this.location,
    required this.tillDate,
    required IconData suffixIcon, // Still required for compatibility, but its value is ignored internally
    required this.jobData,
    required this.jobId, // Make jobId required
  }) : super(key: key);

  @override
  _InfoCardState createState() => _InfoCardState();
}

class _InfoCardState extends State<InfoCard> {
  bool _isSaved = false;
  // IMPORTANT: Get the actual authenticated user's ID from Firebase Auth.
  final User? _currentUser = FirebaseAuth.instance.currentUser; // NEW: Get current user

  @override
  void initState() {
    super.initState();
    _checkIfSaved(); // Check initial saved status when the widget is created
  }

  // Checks if the current job is saved by the user from Firebase
  void _checkIfSaved() async {
    // NEW: Only proceed if a user is logged in
    if (_currentUser == null) {
      print("No user logged in. Cannot check saved status for job: ${widget.jobId}");
      return;
    }

    // NEW: Use the current user's UID to reference their saved jobs
    final ref = FirebaseDatabase.instance.ref('users/${_currentUser!.uid}/savedJobs/${widget.jobId}');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      setState(() {
        _isSaved = true;
      });
    }
  }

  // Toggles the saved status of the job in Firebase
  void _toggleSavedStatus() async {
    // NEW: Prompt user to log in if not authenticated
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to save jobs!")),
      );
      return;
    }

    // NEW: Use the current user's UID to reference their saved jobs
    final ref = FirebaseDatabase.instance.ref('users/${_currentUser!.uid}/savedJobs/${widget.jobId}');
    if (_isSaved) {
      // If currently saved, unsave it (remove from Firebase)
      await ref.remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Job unsaved!")),
      );
    } else {
      // If not saved, save it (add to Firebase)
      // IMPORTANT: When saving, we are saving the entire jobData
      // This makes it easy to retrieve and display in the 'saved.dart' file
      await ref.set(widget.jobData); // NEW: Save the entire jobData map
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Job saved!")),
      );
    }
    // Update the local state to reflect the change
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector( // Wrapped the whole card in GestureDetector for navigation
      onTap: () {
        // Navigate to JobDetailPage when the card itself is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailPage(jobData: widget.jobData, jobId: widget.jobId), // ADDED jobId here
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CircleAvatar(
            //   radius: 20,
            //   backgroundImage: imageUrl != null
            //       ? AssetImage(imageUrl!)
            //       : const AssetImage('assets/images/uet.png') as ImageProvider, // Handle null imageUrl
            // ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis, // Prevent overflow
                        ),
                      ),
                      // The bookmark icon, which now toggles save status
                      IconButton(
                        icon: Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border, // Dynamic icon based on state
                          color: _isSaved ? Colors.orange : Colors.grey, // Dynamic color based on state
                        ),
                        onPressed: _toggleSavedStatus, // Call the toggle function
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${widget.date}  •  ${widget.location}",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // This is line 86, and 'jobData' here refers to the field of this class
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  JobDetailPage(jobData: widget.jobData, jobId: widget.jobId), // ADDED jobId here
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade900,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "More Info",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      Text(
                        "Till ${widget.tillDate}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}