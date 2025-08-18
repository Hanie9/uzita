import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/screens/about_screen.dart';
import 'package:uzita/screens/help_screen.dart';
import 'package:uzita/screens/ticket_list_screen.dart';
import 'package:uzita/screens/editpassword_screen.dart';
import 'package:uzita/screens/home_screen.dart';
import 'package:uzita/services.dart';
import 'package:uzita/wifi.dart';
import 'package:uzita/app_localizations.dart';

class SharedAppDrawer extends StatelessWidget {
  final String username;
  final String userRoleTitle;
  final bool userModir;
  final int userLevel;
  final VoidCallback refreshUserData;
  final VoidCallback logout;
  final bool userActive;

  const SharedAppDrawer({
    super.key,
    required this.username,
    required this.userRoleTitle,
    required this.userModir,
    required this.userLevel,
    required this.refreshUserData,
    required this.logout,
    required this.userActive,
  });

  Future<void> _confirmLogout(BuildContext context) async {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection:
            Provider.of<SettingsProvider>(
                  ctx,
                  listen: false,
                ).selectedLanguage ==
                'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: theme.cardTheme.color,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text(
                localizations.shareddrawer_logout,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          content: Text(
            localizations.shareddrawer_logout_confirm,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(localizations.shareddrawer_no),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(localizations.shareddrawer_yes),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.lapisLazuli,
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 160,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: AppColors.lapisLazuli,
                      ),
                    ),
                    Spacer(),
                    Text(
                      username,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${localizations.shareddrawer_level_user} $userRoleTitle',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.home_outlined),
                  title: Text(localizations.shareddrawer_home),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => HomeScreen()),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.refresh_outlined),
                  title: Text(localizations.shareddrawer_refresh_data),
                  onTap: () {
                    Navigator.pop(context);
                    refreshUserData();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text(localizations.shareddrawer_change_password),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChangePasswordScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text(localizations.shareddrawer_help),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HelpScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text(localizations.shareddrawer_about),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AboutScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.headset_mic_outlined),
                  title: Text(localizations.shareddrawer_support),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TicketListScreen()),
                  ),
                ),
                if (userModir) ...{
                  ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text(localizations.shareddrawer_services),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ServiceListScreen()),
                    ),
                  ),
                },
                // Wifi config should be visible to all users
                ListTile(
                  leading: Icon(Icons.wifi_outlined),
                  title: Text(localizations.shareddrawer_wifi_config),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WifiConfigPage()),
                  ),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.logout),
                  title: Text(localizations.shareddrawer_logout),
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
