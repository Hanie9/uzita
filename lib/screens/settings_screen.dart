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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const Color accentColor = Color(0xFF007BA7);
                      final BorderRadius menuRadius = BorderRadius.circular(
                        ui.scale(base: 12, min: 8, max: 16),
                      );
                      final Color menuColor = isDark
                          ? Colors.grey[800]!
                          : Colors.grey[50]!;
                      final Color borderColor = isDark
                          ? Colors.grey[600]!
                          : Colors.grey[300]!;
                      final List<MapEntry<String, String>> languageOptions = [
                        const MapEntry('fa', 'فارسی'),
                        const MapEntry('en', 'English'),
                      ];
                      final String selectedLabel = languageOptions
                          .firstWhere(
                            (e) => e.key == dropdownValue,
                            orElse: () => languageOptions.first,
                          )
                          .value;

                      Future<void> changeLanguage(String newValue) async {
                        print(
                          'DEBUG: [settings_screen] Language dropdown changed to: $newValue, current: ${settings.selectedLanguage}',
                        );
                        if (newValue == settings.selectedLanguage) {
                          return;
                        }
                        try {
                          if (!context.mounted) return;
                          print(
                            'DEBUG: [settings_screen] Updating language to $newValue',
                          );
                          await settings.setLanguage(newValue);
                          print(
                            'DEBUG: [settings_screen] Language updated in settings',
                          );
                          if (!context.mounted) return;
                        } catch (e) {
                          // print('Error changing language: $e');
                        }
                      }

                      return MenuAnchor(
                        consumeOutsideTap: true,
                        alignmentOffset: const Offset(0, 4),
                        style: MenuStyle(
                          backgroundColor: WidgetStatePropertyAll(menuColor),
                          elevation: const WidgetStatePropertyAll(4),
                          shadowColor: WidgetStatePropertyAll(
                            Colors.black.withValues(alpha: 0.12),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: menuRadius,
                              side: BorderSide(color: borderColor),
                            ),
                          ),
                          minimumSize: WidgetStatePropertyAll(
                            Size(constraints.maxWidth, 0),
                          ),
                          maximumSize: WidgetStatePropertyAll(
                            Size(constraints.maxWidth, 240),
                          ),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                        menuChildren: languageOptions.map((option) {
                          final bool isSelected = dropdownValue == option.key;
                          return MenuItemButton(
                            onPressed: () => changeLanguage(option.key),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (isSelected) {
                                  return accentColor.withValues(alpha: 0.18);
                                }
                                return Colors.transparent;
                              }),
                            ),
                            child: SizedBox(
                              width: constraints.maxWidth - 24,
                              child: Text(
                                option.value,
                                style: TextStyle(
                                  fontFamily: 'Vazir',
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? accentColor
                                      : (isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A)),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                        builder: (context, controller, child) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: menuRadius,
                              onTap: () {
                                if (controller.isOpen) {
                                  controller.close();
                                } else {
                                  FocusScope.of(context).unfocus();
                                  controller.open();
                                }
                              },
                              child: InputDecorator(
                                isEmpty: false,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: menuRadius,
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: menuRadius,
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: menuRadius,
                                    borderSide: const BorderSide(
                                      color: accentColor,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: menuColor,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: ui.scale(
                                      base: 12,
                                      min: 10,
                                      max: 16,
                                    ),
                                    vertical: ui.scale(
                                      base: 14,
                                      min: 12,
                                      max: 16,
                                    ),
                                  ),
                                  suffixIcon: Icon(
                                    controller.isOpen
                                        ? Icons.arrow_drop_up
                                        : Icons.arrow_drop_down,
                                    color: accentColor,
                                  ),
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    selectedLabel,
                                    style: TextStyle(
                                      fontFamily: 'Vazir',
                                      fontSize: 16,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF111111),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
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
