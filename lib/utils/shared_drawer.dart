import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/screens/about_screen.dart';
import 'package:uzita/screens/help_screen.dart';
import 'package:uzita/screens/ticket_list_screen.dart';
import 'package:uzita/screens/editpassword_screen.dart';
import 'package:uzita/screens/home_screen.dart';
import 'package:uzita/screens/transport_requests_screen.dart';
import 'package:uzita/services.dart';
import 'package:uzita/wifi.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Builds the "Services" tile conditionally based on user role and organ_type.
  // For any user whose organ_type is 'technician', this tile must be hidden.
  Widget _buildServicesTile({
    required BuildContext context,
    required double leadingWidth,
    required double iconSize,
    required EdgeInsetsGeometry tilePadding,
    required double tileMinVerticalPad,
    required double horizontalTitleGap,
    required bool useDense,
    required double verticalDensity,
    required int userLevel,
    required bool userModir,
  }) {
    final localizations = AppLocalizations.of(context)!;

    // Only level 1 + modir users are candidates to see "Services"
    if (userLevel != 1 || !userModir) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (BuildContext ctx, AsyncSnapshot<SharedPreferences> snap) {
        final String organType =
            (snap.data?.getString('organ_type') ?? '').toLowerCase();
        final bool isTechnicianOrgan = organType == 'technician';

        if (isTechnicianOrgan) {
          // For technician organizations, hide Services in drawer
          return const SizedBox.shrink();
        }

        return ListTile(
          minLeadingWidth: leadingWidth,
          leading: Icon(
            Icons.settings_outlined,
            size: iconSize,
          ),
          title: Text(
            localizations.shareddrawer_services,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          contentPadding: tilePadding,
          minVerticalPadding: tileMinVerticalPad,
          horizontalTitleGap: horizontalTitleGap,
          dense: useDense,
          visualDensity: VisualDensity(
            vertical: verticalDensity,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceListScreen(),
            ),
          ),
        );
      },
    );
  }

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
    final ui = UiScale(context);
    final Size screenSize = MediaQuery.of(context).size;
    // Responsive, consistent sizing across phones using UiScale
    final double headerHeight = ui.scale(
      base: screenSize.width * 0.36,
      min: 110,
      max: 190,
    );
    final double usernameFont = ui.scale(
      base: screenSize.width * 0.052,
      min: 15,
      max: 21,
    );
    final double roleFont = ui.scale(
      base: screenSize.width * 0.036,
      min: 11.5,
      max: 15,
    );

    // Responsive drawer width (like the screenshots): ~82% of screen, clamped
    final double drawerWidth = (MediaQuery.of(context).size.width * 0.75).clamp(
      260.0,
      360.0,
    );

    return Drawer(
      width: drawerWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int tileCount = 9 + (userLevel == 1 ? 1 : 0);
          const double approxTileHeight = 56.0;
          final double estimatedContentHeight =
              headerHeight + (tileCount * approxTileHeight);
          final double availableHeight = constraints.maxHeight;
          double scaleDown = 1.0;
          if (estimatedContentHeight > availableHeight) {
            scaleDown = (availableHeight - 24.0) / estimatedContentHeight;
            if (scaleDown < 0.6) scaleDown = 0.6;
          }

          final double topPad = MediaQuery.of(context).padding.top;
          final double headerH = (headerHeight * scaleDown).clamp(
            110.0,
            (availableHeight - topPad) * 0.30,
          );
          final double shortestSide = MediaQuery.of(context).size.shortestSide;
          final double avatarR = (shortestSide * 0.11).clamp(24.0, 40.0);
          // Consistent icon sizing across devices
          final double iconSize = (shortestSide * 0.06).clamp(20.0, 24.0);
          final bool isRTL = Directionality.of(context) == TextDirection.rtl;
          final double usernameFs = (usernameFont * scaleDown).clamp(
            16.0,
            22.0,
          );
          final double roleFs = (roleFont * scaleDown).clamp(12.0, 16.0);
          final double bottomPad =
              (MediaQuery.of(context).padding.bottom +
              ui.scale(base: 8, min: 6, max: 12));
          final bool useDense = scaleDown < 0.98;
          double verticalDensity = (-4.0 * (1.0 - scaleDown)).clamp(-3.5, 0.0);
          // Make tiles closer on small phones regardless of scaleDown
          if (ui.isVerySmallPhone && verticalDensity > -4.0) {
            verticalDensity = -4.0;
          } else if (ui.isSmallPhone && verticalDensity > -3.5) {
            verticalDensity = -3.5;
          }
          // Additional compacting for small phones and when scaled
          final double phoneFactor = ui.isVerySmallPhone
              ? 0.75
              : (ui.isSmallPhone ? 0.82 : 1.0);
          final double densityFactor = scaleDown < phoneFactor
              ? scaleDown
              : phoneFactor;
          final EdgeInsets tilePadding = EdgeInsets.symmetric(
            horizontal: (16.0 * densityFactor).clamp(10.0, 18.0),
          );
          final double leadingWidth = (iconSize + 8).clamp(26.0, 32.0);
          final double tileMinVerticalPad = ui.isVerySmallPhone
              ? 0.0
              : (ui.isSmallPhone ? 1.0 : 3.0);
          final double horizontalTitleGap = ui.isVerySmallPhone
              ? 2.0
              : (ui.isSmallPhone ? 4.0 : 8.0);
          // final bool shouldScroll = estimatedContentHeight > availableHeight; // no longer needed

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.lapisLazuli,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 10 * scaleDown,
                ),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: headerH,
                    width: double.infinity,
                    child: FittedBox(
                      alignment: AlignmentDirectional.bottomStart,
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 10 * scaleDown),
                          Align(
                            alignment: isRTL
                                ? AlignmentDirectional.topEnd
                                : AlignmentDirectional.topStart,
                            child: CircleAvatar(
                              radius: avatarR,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                size: avatarR + 5,
                                color: AppColors.lapisLazuli,
                              ),
                            ),
                          ),
                          SizedBox(height: 8 * scaleDown),
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: usernameFs,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4 * scaleDown),
                          Text(
                            '${localizations.shareddrawer_level_user} $userRoleTitle',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: roleFs,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverList(
                      delegate: SliverChildListDelegate([
                        ListTile(
                          minLeadingWidth: leadingWidth,
                          leading: Icon(Icons.home_outlined, size: iconSize),
                          title: Text(
                            localizations.shareddrawer_home,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          contentPadding: tilePadding,
                          minVerticalPadding: tileMinVerticalPad,
                          horizontalTitleGap: horizontalTitleGap,
                          dense: useDense,
                          visualDensity: VisualDensity(
                            vertical: verticalDensity,
                          ),
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => HomeScreen()),
                          ),
                        ),
                        ListTile(
                          minLeadingWidth: leadingWidth,
                          leading: Icon(Icons.refresh_outlined, size: iconSize),
                          title: Text(
                            localizations.shareddrawer_refresh_data,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          contentPadding: tilePadding,
                          minVerticalPadding: tileMinVerticalPad,
                          horizontalTitleGap: horizontalTitleGap,
                          dense: useDense,
                          visualDensity: VisualDensity(
                            vertical: verticalDensity,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            refreshUserData();
                          },
                        ),
                        ListTile(
                          minLeadingWidth: leadingWidth,
                          leading: Icon(Icons.lock_outline, size: iconSize),
                          title: Text(
                            localizations.shareddrawer_change_password,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          contentPadding: tilePadding,
                          minVerticalPadding: tileMinVerticalPad,
                          horizontalTitleGap: horizontalTitleGap,
                          dense: useDense,
                          visualDensity: VisualDensity(
                            vertical: verticalDensity,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChangePasswordScreen(),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          minLeadingWidth: leadingWidth,
                          leading: Icon(Icons.help_outline, size: iconSize),
                          title: Text(
                            localizations.shareddrawer_help,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          contentPadding: tilePadding,
                          minVerticalPadding: tileMinVerticalPad,
                          horizontalTitleGap: horizontalTitleGap,
                          dense: useDense,
                          visualDensity: VisualDensity(
                            vertical: verticalDensity,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => HelpScreen()),
                            );
                          },
                        ),
                        ListTile(
                          minLeadingWidth: leadingWidth,
                          leading: Icon(Icons.info_outline, size: iconSize),
                          title: Text(
                            localizations.shareddrawer_about,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          contentPadding: tilePadding,
                          minVerticalPadding: tileMinVerticalPad,
                          horizontalTitleGap: horizontalTitleGap,
                          dense: useDense,
                          visualDensity: VisualDensity(
                            vertical: verticalDensity,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AboutScreen()),
                            );
                          },
                        ),
                        ListTile(
                          minLeadingWidth: leadingWidth,
                          leading: Icon(
                            Icons.headset_mic_outlined,
                            size: iconSize,
                          ),
                          title: Text(
                            localizations.shareddrawer_support,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          contentPadding: tilePadding,
                          minVerticalPadding: tileMinVerticalPad,
                          horizontalTitleGap: horizontalTitleGap,
                          dense: useDense,
                          visualDensity: VisualDensity(
                            vertical: verticalDensity,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TicketListScreen(),
                            ),
                          ),
                        ),
                        // Services – only for real service owners (userLevel 1, modir true, organ_type != technician)
                        _buildServicesTile(
                          context: context,
                          leadingWidth: leadingWidth,
                          iconSize: iconSize,
                          tilePadding: tilePadding,
                          tileMinVerticalPad: tileMinVerticalPad,
                          horizontalTitleGap: horizontalTitleGap,
                          useDense: useDense,
                          verticalDensity: verticalDensity,
                          userLevel: userLevel,
                          userModir: userModir,
                        ),
                        if (userLevel == 1 ||
                            userLevel == 2 ||
                            userLevel == 4 ||
                            userLevel == 6)
                          ListTile(
                            minLeadingWidth: leadingWidth,
                            leading: Icon(
                              Icons.local_shipping_outlined,
                              size: iconSize,
                            ),
                            title: Text(
                              localizations.shareddrawer_transport_requests,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            contentPadding: tilePadding,
                            minVerticalPadding: tileMinVerticalPad,
                            horizontalTitleGap: horizontalTitleGap,
                            dense: useDense,
                            visualDensity: VisualDensity(
                              vertical: verticalDensity,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TransportRequestsScreen(),
                              ),
                            ),
                          ),
                        ListTile(
                          minLeadingWidth: leadingWidth,
                          leading: Icon(Icons.wifi_outlined, size: iconSize),
                          title: Text(
                            localizations.shareddrawer_wifi_config,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          contentPadding: tilePadding,
                          minVerticalPadding: tileMinVerticalPad,
                          horizontalTitleGap: horizontalTitleGap,
                          dense: useDense,
                          visualDensity: VisualDensity(
                            vertical: verticalDensity,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => WifiConfigPage()),
                          ),
                        ),
                      ]),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Divider(),
                          ListTile(
                            minLeadingWidth: leadingWidth,
                            leading: Icon(Icons.logout, size: iconSize),
                            title: Text(
                              localizations.shareddrawer_logout,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            contentPadding: tilePadding,
                            minVerticalPadding: tileMinVerticalPad,
                            horizontalTitleGap: horizontalTitleGap,
                            dense: useDense,
                            visualDensity: VisualDensity(
                              vertical: verticalDensity,
                            ),
                            onTap: () => _confirmLogout(context),
                          ),
                          SizedBox(height: bottomPad),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
