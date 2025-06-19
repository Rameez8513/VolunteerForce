import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddJobPage extends StatefulWidget {
  const AddJobPage({Key? key}) : super(key: key);

  @override
  _AddJobPageState createState() => _AddJobPageState();
}

class _AddJobPageState extends State<AddJobPage> {
  final titleController = TextEditingController();
  final dateController = TextEditingController();
  final locationController = TextEditingController();
  final requirementController = TextEditingController();
  final descriptionController = TextEditingController();
  final lastDateController = TextEditingController();

  // Variable to hold the selected category
  String? _selectedCategory;

  // List of categories for the dropdown
  final List<String> _categories = [
    'Animal Welfare',
    'Volunteering',
    'Healthcare',
    'Education Sector',
    'Food',
    'Environment',
    'Community Support',
    'Disaster Relief',
    'Arts & Culture',
    'Sports & Recreation',
  ];

  final database = FirebaseDatabase.instance.ref().child("jobs/jobdata");

  void postJob() {
    // Get the current user from Firebase Auth
    final User? currentUser = FirebaseAuth.instance.currentUser;

    // Check if a user is logged in
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to post a job.")),
      );
      return; // Stop the function if no user is logged in
    }

    // Validate all form fields
    if (titleController.text.isEmpty ||
        dateController.text.isEmpty ||
        locationController.text.isEmpty ||
        requirementController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        lastDateController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields and select a category")),
      );
      return;
    }

    // Create the job data map
    final job = {
      'title': titleController.text.trim(),
      'date': dateController.text.trim(), // Date will be in 'YYYY-MM-DD' format
      'location': locationController.text.trim(),
      'requirements': requirementController.text.trim(),
      'description': descriptionController.text.trim(),
      'last_date': lastDateController.text.trim(), // Date will be in 'YYYY-MM-DD' format
      'category': _selectedCategory,
      'posted_on': DateTime.now().toIso8601String(),
      'posted_by_uid': currentUser.uid, // <--- THIS IS THE KEY ADDITION!
    };

    // Push the job data to Firebase Realtime Database
    database.push().set(job).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Job posted successfully!")),
      );
      clearForm(); // Clear the form after successful post
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error posting job: $error")),
      );
    });
  }

  void clearForm() {
    titleController.clear();
    dateController.clear();
    locationController.clear();
    requirementController.clear();
    descriptionController.clear();
    lastDateController.clear();
    setState(() {
      _selectedCategory = null; // Clear selected category
    });
  }

  // --- NEW METHOD: Date Picker Function ---
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade900, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.indigo.shade900, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().substring(0, 10); // Format as YYYY-MM-DD
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.indigo.shade900,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Add a job',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                    TextButton(
                      onPressed: postJob,
                      child: const Text("Post",
                          style: TextStyle(color: Colors.orange)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Input fields
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        buildInputField("Volunteer Work Title", titleController,
                            "Tree Plantation Drive"),
                        // Category Dropdown
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: "Category",
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text("Select a category"),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedCategory = newValue;
                              });
                            },
                            items: _categories.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                        // Date of Posting field with DatePicker
                        // --- MODIFIED buildInputField call for date picker ---
                        GestureDetector(
                          onTap: () => _selectDate(context, dateController),
                          child: AbsorbPointer( // Prevents direct keyboard input
                            child: buildInputField(
                              "Date of Posting",
                              dateController,
                              "YYYY-MM-DD (e.g., 2025-05-25)", // Updated hint
                            ),
                          ),
                        ),
                        // --- END MODIFIED ---
                        buildInputField("Job Location", locationController,
                            "Lahore, Pakistan"),
                        buildInputField("Requirements", requirementController,
                            "10 volunteers with tools"),
                        buildInputField("Description", descriptionController,
                            "Help plant 500 trees in campus."),
                        // Last Date to Apply field with DatePicker
                        // --- MODIFIED buildInputField call for date picker ---
                        GestureDetector(
                          onTap: () => _selectDate(context, lastDateController),
                          child: AbsorbPointer( // Prevents direct keyboard input
                            child: buildInputField(
                              "Last Date to Apply",
                              lastDateController,
                              "YYYY-MM-DD (e.g., 2025-06-01)", // Updated hint
                            ),
                          ),
                        ),
                        // --- END MODIFIED ---
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInputField(
      String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        readOnly: label.contains('Date'), // Make date fields read-only
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          // Add a calendar icon for date fields
          suffixIcon: label.contains('Date') ? const Icon(Icons.calendar_today) : null,
        ),
      ),
    );
  }
}