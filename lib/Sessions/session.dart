import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _isLoggedIn = "isLoggedIn";
  static const String _loginTime = "loginTime";

  // Save login time and status
  static Future<void> saveLoginSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedIn, true);
    await prefs.setString(_loginTime, DateTime.now().toIso8601String());
  }

  // Clear session
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedIn);
    await prefs.remove(_loginTime);
  }

  // Check if session is valid (within 24 hours)
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    bool? loggedIn = prefs.getBool(_isLoggedIn);
    String? timeString = prefs.getString(_loginTime);

    if (loggedIn == true && timeString != null) {
      DateTime loginTime = DateTime.parse(timeString);
      return DateTime.now().difference(loginTime).inHours < 24;
    }
    return false;
  }
}