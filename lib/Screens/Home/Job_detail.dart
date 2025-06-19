import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobDetailPage extends StatelessWidget {
  final Map<String, dynamic> jobData;
  final String jobId; // The unique ID of the specific job

  const JobDetailPage({Key? key, required this.jobData, required this.jobId}) : super(key: key);

  // Helper method to build consistent detail rows
  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      return const SizedBox.shrink(); // Don't display if value is null or empty
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              value.toString(), // Convert to string for display
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    );
  }

  // Method to submit application data to Firebase directly (without form fields)
  Future<void> _submitDirectApplication(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to apply for a job.')),
      );
      return;
    }

    try {
      final DatabaseReference applicationsRef = FirebaseDatabase.instance.ref('applications');
      final newApplicationRef = applicationsRef.push(); // Generate a unique ID for the new application

      // Save application details without user-input fields
      await newApplicationRef.set({
        'jobId': jobId,
        'applicantUid': user.uid, // Store the UID of the user applying
        'applicantEmail': user.email, // Use current user's email
        'applicationDate': DateTime.now().toIso8601String(),
        'jobTitle': jobData['title'],
        'jobLocation': jobData['location'],
        // You can add more job-specific data if needed
      });

      // Crucial: Update the user's appliedJobs list
      // This marks the job as "applied" for the current user
      final userAppliedJobsRef = FirebaseDatabase.instance.ref('users/${user.uid}/appliedJobs');
      await userAppliedJobsRef.child(jobId).set(true); // Set job ID as true

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Application submitted successfully!')),
      );

      // Pop the current JobDetailPage and then ensure ProfilePage refreshes
      // A common way to achieve this is to pop, and then when ProfilePage rebuilds,
      // its initState will call _fetchAppliedJobs() again.
      Navigator.of(context).pop();

    } catch (e) {
      print("Error submitting application: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit application. Please try again.')),
      );
    }
  }

  // NEW METHOD: Check if the user has already applied for this job
  Future<bool> _checkIfAlreadyApplied(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // If no user is logged in, they can't have applied
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to check application status.')),
      );
      return false;
    }

    try {
      final userAppliedJobsRef = FirebaseDatabase.instance.ref('users/${user.uid}/appliedJobs');
      final snapshot = await userAppliedJobsRef.child(jobId).get();

      // If snapshot exists and its value is true, the user has applied
      return snapshot.exists && snapshot.value == true;
    } catch (e) {
      print("Error checking application status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking application status.')),
      );
      return false; // Assume not applied on error to allow retrying
    }
  }


  // Function to show the confirmation dialog
  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Confirm Application'),
          content: Text('Are you sure you want to apply for "${jobData['title'] ?? 'this job'}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss the dialog
              },
            ),
            ElevatedButton(
              child: const Text('OK', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade900,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss the confirmation dialog
                _submitDirectApplication(context); // Then proceed with application
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          jobData['title'] ?? 'Job Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo.shade900,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Logo - dynamic based on 'imageUrl'
                  CircleAvatar(
                    backgroundImage: AssetImage(
                      jobData['imageUrl'] ?? 'assets/images/google_logo.png',
                    ),
                    radius: 30,
                    backgroundColor: Colors.transparent,
                  ),
                  SizedBox(height: 10),

                  // Job Title - dynamic based on 'title'
                  Text(
                    jobData['title'] ?? 'Job Title Not Available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Display Date, Location, and Till Date
                  _buildDetailRow('Date Posted', jobData['date']),
                  _buildDetailRow('Location', jobData['location']),
                  _buildDetailRow('Apply Till', jobData['tillDate']),
                  SizedBox(height: 20),

                  // Job Description Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Job Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    jobData['description'] ?? 'No description provided.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 20),

                  // Requirements Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Requirements',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  if (jobData['requirements'] is List)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (jobData['requirements'] as List<dynamic>)
                          .map((req) => Text(
                                '• ${req.toString()}',
                                style: TextStyle(fontSize: 14),
                              ))
                          .toList(),
                    )
                  else
                    Text(
                      jobData['requirements']?.toString() ?? 'No specific requirements listed.',
                      style: TextStyle(fontSize: 14),
                    ),

                  SizedBox(height: 20),

                  // Location Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      jobData['location'] ?? 'Location not specified',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                  SizedBox(height: 15),

                  SizedBox(height: 25),

                  // Apply Now Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // First, check if already applied
                        bool alreadyApplied = await _checkIfAlreadyApplied(context);
                        if (alreadyApplied) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('You have already applied for this job!')),
                          );
                        } else {
                          // If not already applied, show the confirmation dialog
                          _showConfirmationDialog(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'APPLY NOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}