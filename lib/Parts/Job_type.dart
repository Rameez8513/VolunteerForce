import 'package:flutter/material.dart';
import 'package:ramiz_app/Screens/Home/Available_jobs.dart'; // Import the AvailableJobsPage

class CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int jobCount; // CHANGED: Now takes an int for the job count
  final Color backgroundColor;
  final String categoryName;

  const CategoryCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.jobCount, // CHANGED: Required jobCount
    this.backgroundColor = const Color(0xFFFFFFFF),
    required this.categoryName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Navigate to AvailableJobsPage and pass the categoryName
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AvailableJobsPage(
              selectedCategory: categoryName, // Pass the category name
              categoryTitle: title,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(15), // Ripple effect looks better
      child: Container(
        width: 105, // Adjusted width slightly to fit more cards per row if needed
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.orange),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Text(
              // UPDATED: Format the jobCount into a string here
              "$jobCount Jobs",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}