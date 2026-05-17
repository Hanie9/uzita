import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;

typedef OrgTaskAssignmentCallback = void Function(
  String username,
  Map<String, dynamic> updatedFields,
);

Future<List<Map<String, String>>> fetchOrganTechnicianUsers() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');
    if (token == null || token.isEmpty) return <Map<String, String>>[];

    await SessionManager().onNetworkRequest();

    final Uri url = Uri.parse('$apiBaseUrl/listuser/').replace(
      queryParameters: <String, String>{
        'ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final http.Response response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Connection': 'close',
      },
    );

    if (response.statusCode != 200) return <Map<String, String>>[];

    final dynamic data = json.decode(utf8.decode(response.bodyBytes));
    List<dynamic> rawUsers = <dynamic>[];

    if (data is List) {
      rawUsers = data;
    } else if (data is Map && data['results'] is List) {
      rawUsers = List<dynamic>.from(data['results'] as List);
    } else if (data is Map && data['data'] is List) {
      rawUsers = List<dynamic>.from(data['data'] as List);
    }

    return rawUsers
        .map<Map<String, String>>((dynamic item) {
          final Map<String, dynamic> map = item is Map<String, dynamic>
              ? item
              : <String, dynamic>{};
          final dynamic userData = map['user'] ?? map;
          final Map<String, dynamic> user = userData is Map<String, dynamic>
              ? userData
              : <String, dynamic>{};

          final String username = (user['username'] ?? '').toString().trim();
          final String firstName = (user['first_name'] ?? '').toString().trim();
          final String lastName = (user['last_name'] ?? '').toString().trim();
          String display = username;
          final String fullName = '$firstName $lastName'.trim();
          if (fullName.isNotEmpty) {
            display = '$fullName ($username)';
          }

          return <String, String>{'username': username, 'display': display};
        })
        .where((Map<String, String> u) => u['username']!.isNotEmpty)
        .toList();
  } catch (_) {
    return <Map<String, String>>[];
  }
}

Future<bool> assignOrganTask({
  required dynamic taskId,
  required String username,
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');
  if (token == null || token.isEmpty) return false;

  await SessionManager().onNetworkRequest();

  final Uri url = Uri.parse(
    '$apiBaseUrl/technician-organ/tasks/$taskId/assignment',
  );

  final http.Response response = await http.post(
    url,
    headers: <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: json.encode(<String, String>{'username': username}),
  );

  return response.statusCode == 200 || response.statusCode == 201;
}

Future<void> showOrganTaskAssignmentDialog({
  required BuildContext context,
  required Map<String, dynamic> task,
  OrgTaskAssignmentCallback? onAssigned,
}) async {
  final AppLocalizations loc = AppLocalizations.of(context)!;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return const Center(child: CircularProgressIndicator());
    },
  );

  final List<Map<String, String>> users = await fetchOrganTechnicianUsers();

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (users.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final AppLocalizations dialogLoc = AppLocalizations.of(ctx)!;
        return AlertDialog(
          backgroundColor: Theme.of(ctx).cardTheme.color,
          title: Text(dialogLoc.tech_assign_dialog_title),
          content: Text(dialogLoc.tech_assign_dialog_no_users),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(dialogLoc.tech_assign_dialog_ok),
            ),
          ],
        );
      },
    );
    return;
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String currentUsername = prefs.getString('username') ?? '';
  String? selectedUsername =
      currentUsername.trim().isNotEmpty ? currentUsername.trim() : null;

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (
          BuildContext ctx,
          void Function(void Function()) setStateDialog,
        ) {
          final AppLocalizations dialogLoc = AppLocalizations.of(ctx)!;
          return AlertDialog(
            backgroundColor: Theme.of(ctx).cardTheme.color,
            title: Text(
              dialogLoc.tech_assign_dialog_title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, String> user = users[index];
                  final String username = user['username']!;
                  final String display = user['display']!;
                  final bool isChecked = selectedUsername == username;

                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: (bool? checked) {
                      setStateDialog(() {
                        if (checked == true) {
                          selectedUsername = username;
                        } else if (selectedUsername == username) {
                          selectedUsername = null;
                        }
                      });
                    },
                    title: Text(display),
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogLoc.tech_assign_dialog_cancel),
              ),
              ElevatedButton(
                onPressed: selectedUsername == null
                    ? null
                    : () async {
                        final String username = selectedUsername!.trim();
                        if (username.isEmpty) return;
                        Navigator.of(dialogContext).pop();

                        final bool ok = await assignOrganTask(
                          taskId: task['id'],
                          username: username,
                        );

                        if (!context.mounted) return;

                        if (ok) {
                          final Map<String, dynamic> updated =
                              <String, dynamic>{
                            'status': 'assigned',
                            'technician': username,
                            'technician_username': username,
                            'assigned_username': username,
                          };
                          onAssigned?.call(username, updated);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.tech_assignment_success)),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.tech_assign_error)),
                          );
                        }
                      },
                child: Text(dialogLoc.tech_assign_dialog_assign),
              ),
            ],
          );
        },
      );
    },
  );
}
