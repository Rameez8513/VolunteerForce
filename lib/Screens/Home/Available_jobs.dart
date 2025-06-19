import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ramiz_app/Parts/Post_job.dart'; // Assuming InfoCard is here

class AvailableJobsPage extends StatefulWidget {
  final String selectedCategory;
  final String categoryTitle;

  const AvailableJobsPage({
    Key? key,
    required this.selectedCategory,
    required this.categoryTitle,
  }) : super(key: key);

  @override
  _AvailableJobsPageState createState() => _AvailableJobsPageState();
}

class _AvailableJobsPageState extends State<AvailableJobsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle), // Display the category title
        backgroundColor: Colors.indigo.shade900,
      ),
      body: FutureBuilder<DatabaseEvent>(
        // Filter Firebase query based on the selected category
        future: FirebaseDatabase.instance.ref('jobs/jobdata')
            .orderByChild('category') // Order by the 'category' field
            .equalTo(widget.selectedCategory) // Filter by the selected category
            .once(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(child: Text("No jobs available in this category."));
          }

          final data = snapshot.data!.snapshot.value as Map;
          // Convert the map entries to a list, so we can access both key (jobId) and value (job data)
          final List<MapEntry<dynamic, dynamic>> jobEntries = data.entries.toList();


          if (jobEntries.isEmpty) {
            return Center(child: Text("No jobs available in this category."));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: jobEntries.map((entry) { // Iterate over MapEntry to get key and value
                final jobId = entry.key; // Get the unique job ID from the entry key
                final job = Map<String, dynamic>.from(entry.value); // Get the job data

                return InfoCard(
                  imageUrl: job['imageUrl'] ?? 'assets/images/uet.png',
                  title: job['title'] ?? 'No title',
                  date: job['date'] ?? 'No date',
                  location: job['location'] ?? 'No location',
                  tillDate: job['last_date'] ?? 'No end date',
                  suffixIcon: Icons.bookmark, // This is now ignored by InfoCard's internal state
                  jobData: job,
                  jobId: jobId, // Pass the jobId here!
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
