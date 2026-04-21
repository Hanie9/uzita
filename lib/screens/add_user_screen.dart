import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/main.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/ui_scale.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  int level = 1;
  String message = '';

  Future<void> addUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('$baseUrl/adduser/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'username': usernameController.text,
        'password': passwordController.text,
        'phone': phoneController.text,
        'code': codeController.text,
        'level': level,
      }),
    );
    final data = json.decode(utf8.decode(response.bodyBytes));
    setState(() {
      message =
          data['massage'] ??
          data['error'] ??
          AppLocalizations.of(context)!.adduser_error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.adduser_title),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ui.scale(base: 16, min: 12, max: 20),
            ),
            child: Image.asset(
              'assets/logouzita.png',
              height: ui.scale(base: 32, min: 24, max: 40),
            ),
          ),
          IconButton(
            onPressed: () => setState(() {}),
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ui.scale(base: 16, min: 12, max: 20),
            ui.scale(base: 16, min: 12, max: 20),
            ui.scale(base: 16, min: 12, max: 20),
            ui.scale(base: 16, min: 12, max: 20) +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ui.scale(base: 16, min: 12, max: 20),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(ui.scale(base: 24, min: 16, max: 28)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context)!.adduser_new_info,
                    style: TextStyle(
                      fontSize: ui.scale(base: 20, min: 16, max: 22),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ui.scale(base: 24, min: 16, max: 28)),
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.adduser_username,
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.adduser_password,
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.adduser_phone,
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.adduser_code,
                      prefixIcon: Icon(Icons.code),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      )!.adduser_level_access,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ui.scale(base: 12, min: 10, max: 16),
                        vertical: ui.scale(base: 4, min: 3, max: 6),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: level,
                        isExpanded: true,
                        onChanged: (val) => setState(() => level = val!),
                        items: [1, 2, 3]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  '${AppLocalizations.of(context)!.adduser_level} $e',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: ui.scale(base: 20, min: 14, max: 26)),
                  ElevatedButton.icon(
                    icon: Icon(Icons.person_add),
                    label: Text(AppLocalizations.of(context)!.adduser_submit),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: ui.scale(base: 14, min: 12, max: 16),
                      ),
                    ),
                    onPressed: addUser,
                  ),
                  if (message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        AppLocalizations.of(context)!.adduser_success,
                        style: TextStyle(
                          color: AppColors.lapisLazuli.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
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
