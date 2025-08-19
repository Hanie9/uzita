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
    final Size screenSize = MediaQuery.of(context).size;
    // Responsive, consistent sizing across phones
    final double headerHeight = (screenSize.width * 0.36).clamp(120.0, 180.0);
    final double avatarRadius = (screenSize.width * 0.14).clamp(28.0, 40.0);
    final double usernameFont = (screenSize.width * 0.052).clamp(16.0, 20.0);
    final double roleFont = (screenSize.width * 0.036).clamp(12.0, 14.0);

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.lapisLazuli,
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: headerHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: avatarRadius + 5,
                        color: AppColors.lapisLazuli,
                      ),
                    ),
                    Spacer(),
                    Text(
                      username,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: usernameFont,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${localizations.shareddrawer_level_user} $userRoleTitle',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: roleFont,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
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
