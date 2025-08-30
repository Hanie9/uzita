import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/utils/ui_scale.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    print(
      'DEBUG: [settings_screen] build called, selectedLanguage: ${Provider.of<SettingsProvider>(context).selectedLanguage}',
    );
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final theme = Theme.of(context);
        final isDark = settings.darkModeEnabled;
        final localizations = AppLocalizations.of(context)!;
        final dropdownValue =
            (settings.selectedLanguage == 'en' ||
                settings.selectedLanguage == 'fa')
            ? settings.selectedLanguage
            : 'fa';
        final ui = UiScale(context);
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: Container(
              color: theme.appBarTheme.backgroundColor,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        localizations.set_title,
                        style: theme.appBarTheme.titleTextStyle,
                      ),
                      Spacer(),
                      Image.asset(
                        'assets/logouzita.png',
                        height: MediaQuery.of(context).size.height * 0.08,
                        width: MediaQuery.of(context).size.height * 0.08,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: Directionality(
            textDirection: settings.selectedLanguage == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                ui.scale(base: 16, min: 12, max: 20),
                ui.scale(base: 16, min: 12, max: 20),
                ui.scale(base: 16, min: 12, max: 20),
                ui.scale(base: 16, min: 12, max: 20) +
                    MediaQuery.of(context).padding.bottom,
              ),
              children: [
                _buildSettingSection(
                  context: context,
                  title: localizations.set_notifications_title,
                  subtitle: localizations.set_notifications_subtitle,
                  child: SwitchListTile(
                    value: settings.notificationsEnabled,
                    onChanged: (value) => settings.setNotifications(value),
                    title: Text(
                      localizations.set_notifications_toggle,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    activeColor: Color(0xFF007BA7),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                _buildSettingSection(
                  context: context,
                  title: localizations.set_appearance_title,
                  subtitle: localizations.set_appearance_subtitle,
                  child: SwitchListTile(
                    value: settings.darkModeEnabled,
                    onChanged: (value) => settings.setDarkMode(value),
                    title: Text(
                      localizations.set_dark_mode,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    activeColor: Color(0xFF007BA7),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                _buildSettingSection(
                  context: context,
                  title: localizations.set_text_size_title,
                  subtitle: localizations.set_text_size_subtitle,
                  child: Column(
                    children: [
                      Slider(
                        value: settings.textSize,
                        min: 0.8,
                        max: 1.2,
                        divisions: 4,
                        label: '${(settings.textSize * 100).round()}%',
                        onChanged: (value) {
                          settings.setTextSize(value);
                        },
                        activeColor: Color(0xFF007BA7),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localizations.set_text_small,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                          Text(
                            localizations.set_text_normal,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                          Text(
                            localizations.set_text_large,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildSettingSection(
                  context: context,
                  title: localizations.set_app_language_title,
                  subtitle: localizations.set_change_language_subtitle,
                  child: DropdownButtonFormField<String>(
                    value: dropdownValue,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      fillColor: isDark ? Colors.grey[800] : Colors.white,
                      filled: true,
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                    dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                    items: [
                      DropdownMenuItem<String>(
                        value: 'fa',
                        child: Text(
                          'فارسی',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey[800],
                          ),
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: 'en',
                        child: Text(
                          'English',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (newValue) async {
                      print(
                        'DEBUG: [settings_screen] Language dropdown changed to: $newValue, current: ${settings.selectedLanguage}',
                      );
                      if (newValue != null &&
                          newValue != settings.selectedLanguage) {
                        try {
                          // Show loading dialog
                          if (!context.mounted) return;
                          // showDialog(
                          //   context: context,
                          //   barrierDismissible: false,
                          //   builder: (context) => WillPopScope(
                          //     onWillPop: () async => false,
                          //     child: Center(child: CircularProgressIndicator()),
                          //   ),
                          // );

                          print(
                            'DEBUG: [settings_screen] Updating language to $newValue',
                          );
                          // Update language in settings and wait for it to complete
                          await settings.setLanguage(newValue);
                          print(
                            'DEBUG: [settings_screen] Language updated in settings',
                          );

                          if (!context.mounted) return;

                          // Important: Use a short delay to ensure the language change is applied
                          // await Future.delayed(
                          //   const Duration(milliseconds: 100),
                          // );

                          // Force rebuild the entire app to apply new locale
                          // if (!context.mounted) return;

                          // Pop loading dialog
                          // Navigator.of(context, rootNavigator: true).pop();

                          // // Restart the app from root
                          // if (!context.mounted) return;
                        } catch (e) {
                          // print('Error changing language: $e');
                          // if (!context.mounted) return;
                          // Navigator.of(context, rootNavigator: true).pop();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingSection({
    required BuildContext context,
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = Provider.of<SettingsProvider>(context).darkModeEnabled;
    final ui = UiScale(context);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: ui.scale(base: 8, min: 6, max: 12),
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(ui.scale(base: 16, min: 12, max: 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: ui.scale(base: 16, min: 14, max: 18),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: ui.scale(base: 4, min: 3, max: 6)),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: ui.scale(base: 12, min: 11, max: 14),
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
            SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
            child,
          ],
        ),
      ),
    );
  }
}
