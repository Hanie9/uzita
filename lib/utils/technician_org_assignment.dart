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
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String currentUsername = (prefs.getString('username') ?? '').trim();
  final String currentLower = currentUsername.toLowerCase();

  final List<Map<String, String>> assignableUsers = currentLower.isEmpty
      ? users
      : users
          .where(
            (Map<String, String> u) =>
                u['username']!.trim().toLowerCase() != currentLower,
          )
          .toList();

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (assignableUsers.isEmpty) {
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

  String? selectedUsername;

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (
          BuildContext ctx,
          void Function(void Function()) setStateDialog,
        ) {
          final AppLocalizations dialogLoc = AppLocalizations.of(ctx)!;
          final ThemeData theme = Theme.of(ctx);
          return AlertDialog(
            backgroundColor: theme.cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            title: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007BA7).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_ind_outlined,
                    color: Color(0xFF007BA7),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dialogLoc.tech_assign_dialog_title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${assignableUsers.length} ${dialogLoc.tech_assign_dialog_assign}',
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: assignableUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, String> user = assignableUsers[index];
                        final String username = user['username']!;
                        final String display = user['display']!;
                        final bool isChecked = selectedUsername == username;

                        return Material(
                          color: isChecked
                              ? const Color(0xFF007BA7).withValues(alpha: 0.09)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setStateDialog(() {
                                selectedUsername = isChecked ? null : username;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isChecked
                                      ? const Color(0xFF007BA7)
                                      : theme.dividerColor.withValues(
                                          alpha: 0.45,
                                        ),
                                  width: isChecked ? 1.4 : 1,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    isChecked
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 20,
                                    color: isChecked
                                        ? const Color(0xFF007BA7)
                                        : theme.textTheme.bodyMedium?.color
                                              ?.withValues(alpha: 0.55),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      display,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isChecked
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: theme.textTheme.bodyMedium?.color,
                ),
                child: Text(
                  dialogLoc.tech_assign_dialog_cancel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BA7),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF007BA7,
                  ).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
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
