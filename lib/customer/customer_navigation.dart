import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/services/session_manager.dart';

void openCustomerTab(BuildContext context, int index) {
  final String route = switch (index) {
    1 => '/customer-services',
    2 => '/customer-bars',
    3 => '/customer-tickets',
    4 => '/profile',
    _ => '/home',
  };
  final String? current = ModalRoute.of(context)?.settings.name;
  if (current == route) return;
  Navigator.pushReplacementNamed(context, route);
}

Future<void> customerLogout(BuildContext context) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? saved = prefs.getString('saved_username');
  final String? language = prefs.getString('selectedLanguage');
  final bool? darkMode = prefs.getBool('darkModeEnabled');
  final double? textSize = prefs.getDouble('textSize');
  final bool? notifications = prefs.getBool('notificationsEnabled');

  await SessionManager().endSession(clearBiometric: true);
  await prefs.clear();

  if (saved != null && saved.isNotEmpty) {
    await prefs.setString('saved_username', saved);
  }
  if (language != null && language.isNotEmpty) {
    await prefs.setString('selectedLanguage', language);
  }
  if (darkMode != null) await prefs.setBool('darkModeEnabled', darkMode);
  if (textSize != null) await prefs.setDouble('textSize', textSize);
  if (notifications != null) {
    await prefs.setBool('notificationsEnabled', notifications);
  }

  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
