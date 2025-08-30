import 'package:flutter/material.dart';
import 'package:uzita/services.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/utils/ui_scale.dart';

class SharedBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final int userLevel;
  final Function(int) onItemTapped;

  const SharedBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.userLevel,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ui = UiScale(context);
    final bottomPadding = mq.padding.bottom;
    final localizations = AppLocalizations.of(context)!;

    // Adaptive height using UiScale for consistency across phones
    final double navBarHeight = ui.scale(base: 66, min: 56, max: 74);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: navBarHeight + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: userLevel == 3
            ? [
                // For level 3 users: Home on left, Profile on right
                _buildNavItem(
                  icon: Icons.home,
                  label: localizations.nav_home,
                  isActive: selectedIndex == 0,
                  color: AppColors.lapisLazuli,
                  onTap: () => onItemTapped(0),
                ),
                _buildNavItem(
                  icon: Icons.list_alt,
                  label: localizations.nav_reports,
                  isActive: selectedIndex == 2,
                  color: AppColors.lapisLazuli,
                  onTap: () => onItemTapped(2),
                ),
                _buildNavItem(
                  icon: Icons.devices,
                  label: localizations.nav_devices,
                  isActive: selectedIndex == 1,
                  color: AppColors.lapisLazuli,
                  onTap: () => onItemTapped(1),
                ),
                _buildNavItem(
                  icon: Icons.person,
                  label: localizations.nav_profile,
                  isActive: selectedIndex == 3,
                  color: AppColors.lapisLazuli,
                  onTap: () => onItemTapped(3),
                ),
              ]
            : [
                // For other user levels: original layout
                _buildNavItem(
                  icon: Icons.person,
                  label: localizations.nav_profile,
                  isActive: selectedIndex == 3,
                  color: AppColors.lapisLazuli,
                  onTap: () => onItemTapped(3),
                ),
                // Hide users navigation for level 3 users
                if (userLevel < 3)
                  _buildNavItem(
                    icon: Icons.people,
                    label: localizations.nav_users,
                    isActive: selectedIndex == 4,
                    color: AppColors.lapisLazuli,
                    onTap: () => onItemTapped(4),
                  ),
                // Centered home icon
                _buildNavItem(
                  icon: Icons.home,
                  label: localizations.nav_home,
                  isActive: selectedIndex == 0,
                  color: AppColors.lapisLazuli,
                  onTap: () => onItemTapped(0),
                ),
                _buildNavItem(
                  icon: Icons.list_alt,
                  label: localizations.nav_reports,
                  isActive: selectedIndex == 2,
                  color: AppColors.lapisLazuli,
                  onTap: () => onItemTapped(2),
                ),
                _buildNavItem(
                  icon: Icons.devices,
                  label: localizations.nav_devices,
                  isActive: selectedIndex == 1,
                  color: AppColors.lapisLazuli,
                  onTap: () => onItemTapped(1),
                ),
              ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        // Adaptive sizes via UiScale
        final ui = UiScale(context);
        final double iconSize = ui.scale(base: 24, min: 20, max: 28);
        final double fontSize = ui.scale(base: 11.5, min: 9.5, max: 13);
        final double activeLift = ui.scale(base: 6, min: 4, max: 7);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: onTap,
          child: Transform.translate(
            offset: Offset(0, isActive ? -activeLift : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Icon(
                    icon,
                    color: isActive
                        ? color
                        : (isDark ? Colors.grey[500] : Colors.grey[400]),
                    size: iconSize.clamp(20.0, 30.0),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? color
                        : (isDark ? Colors.grey[500] : Colors.grey[400]),
                    fontSize: fontSize.clamp(9.5, 13.0),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isActive)
                  Container(
                    margin: EdgeInsets.only(top: 1),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
