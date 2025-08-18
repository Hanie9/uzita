import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Widget _buildSectionContainer({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> body,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...body,
          ],
        ),
      ),
    );
  }

  Widget _buildBulletList(
    BuildContext context,
    List<String> items, {
    IconData icon = Icons.circle,
    Color? color,
    double iconSize = 6,
  }) {
    final resolvedColor = color ?? Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(icon, size: iconSize, color: resolvedColor),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Back arrow
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        AppLocalizations.of(context)!.help_title,
                        style: theme.appBarTheme.titleTextStyle,
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),

                  // Right - Logo
                  Row(
                    children: [
                      Image.asset(
                        'assets/logouzita.png',
                        height: screenHeight * 0.08,
                        width: screenHeight * 0.08,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionContainer(
              context: context,
              icon: Icons.info_outline,
              color: Color(0xFF007BA7),
              title: AppLocalizations.of(context)!.help_intro_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_intro_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.app_registration,
              color: Color(0xFF00A86B),
              title: AppLocalizations.of(context)!.help_postpurchase_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_postpurchase_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                _buildBulletList(
                  context,
                  [
                    AppLocalizations.of(context)!.help_postpurchase_bullet_1,
                    AppLocalizations.of(context)!.help_postpurchase_bullet_2,
                    AppLocalizations.of(context)!.help_postpurchase_bullet_3,
                    AppLocalizations.of(context)!.help_postpurchase_bullet_4,
                  ],
                  icon: Icons.circle,
                  color: Color(0xFF00A86B),
                  iconSize: 6,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.devices_other,
              color: Color(0xFF007BA7),
              title: AppLocalizations.of(context)!.help_add_device_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_add_device_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.group_add,
              color: Color(0xFFD4AF37),
              title: AppLocalizations.of(context)!.help_add_users_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_add_users_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                _buildBulletList(
                  context,
                  [
                    AppLocalizations.of(context)!.help_add_users_method_1,
                    AppLocalizations.of(context)!.help_add_users_method_2,
                  ],
                  icon: Icons.circle,
                  color: Color(0xFFD4AF37),
                  iconSize: 6,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.manage_accounts,
              color: Color(0xFF007BA7),
              title: AppLocalizations.of(context)!.help_user_management_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_user_management_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.devices,
              color: Color(0xFF00A86B),
              title: AppLocalizations.of(context)!.help_device_management_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_device_management_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.settings_ethernet,
              color: Color(0xFF007BA7),
              title: AppLocalizations.of(context)!.help_device_config_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_device_config_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.receipt_long,
              color: Color(0xFFD4AF37),
              title: AppLocalizations.of(context)!.help_report_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_report_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                _buildBulletList(
                  context,
                  [
                    AppLocalizations.of(context)!.help_report_bullet_1,
                    AppLocalizations.of(context)!.help_report_bullet_2,
                    AppLocalizations.of(context)!.help_report_bullet_3,
                  ],
                  icon: Icons.check_circle,
                  color: Color(0xFFD4AF37),
                  iconSize: 16,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.security,
              color: Color(0xFF007BA7),
              title: AppLocalizations.of(context)!.help_user_level_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_user_level_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.help_company_rep_title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                _buildBulletList(
                  context,
                  [
                    AppLocalizations.of(context)!.help_company_rep_bullet_1,
                    AppLocalizations.of(context)!.help_company_rep_bullet_2,
                    AppLocalizations.of(context)!.help_company_rep_bullet_3,
                    AppLocalizations.of(context)!.help_company_rep_bullet_4,
                    AppLocalizations.of(context)!.help_company_rep_bullet_5,
                    AppLocalizations.of(context)!.help_company_rep_bullet_6,
                    AppLocalizations.of(context)!.help_company_rep_bullet_7,
                  ],
                  icon: Icons.check_circle,
                  color: Color(0xFF007BA7),
                  iconSize: 16,
                ),
                SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.help_user_level_title_2,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                _buildBulletList(
                  context,
                  [
                    AppLocalizations.of(context)!.help_admin_bullet_1,
                    AppLocalizations.of(context)!.help_admin_bullet_2,
                    AppLocalizations.of(context)!.help_admin_bullet_3,
                    AppLocalizations.of(context)!.help_admin_bullet_4,
                    AppLocalizations.of(context)!.help_admin_bullet_5,
                    AppLocalizations.of(context)!.help_admin_bullet_6,
                    AppLocalizations.of(context)!.help_admin_bullet_7,
                  ],
                  icon: Icons.check_circle,
                  color: Color(0xFF007BA7),
                  iconSize: 16,
                ),
                SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.help_installer_title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                _buildBulletList(
                  context,
                  [
                    AppLocalizations.of(context)!.help_installer_bullet_1,
                    AppLocalizations.of(context)!.help_installer_bullet_2,
                    AppLocalizations.of(context)!.help_installer_bullet_3,
                    AppLocalizations.of(context)!.help_installer_bullet_4,
                    AppLocalizations.of(context)!.help_installer_bullet_5,
                  ],
                  icon: Icons.check_circle,
                  color: Color(0xFF007BA7),
                  iconSize: 16,
                ),
                SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.help_regular_user_title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                _buildBulletList(
                  context,
                  [
                    AppLocalizations.of(context)!.help_regular_user_bullet_1,
                    AppLocalizations.of(context)!.help_regular_user_bullet_2,
                    AppLocalizations.of(context)!.help_regular_user_bullet_3,
                    AppLocalizations.of(context)!.help_regular_user_bullet_4,
                  ],
                  icon: Icons.check_circle,
                  color: Color(0xFF007BA7),
                  iconSize: 16,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.settings,
              color: Color(0xFF00A86B),
              title: AppLocalizations.of(context)!.help_user_settings_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_user_settings_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
                SizedBox(height: 12),
                _buildBulletList(
                  context,
                  [
                    AppLocalizations.of(context)!.help_user_settings_bullet_1,
                    AppLocalizations.of(context)!.help_user_settings_bullet_2,
                    AppLocalizations.of(context)!.help_user_settings_bullet_3,
                  ],
                  icon: Icons.circle,
                  color: Color(0xFF00A86B),
                  iconSize: 6,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.account_circle,
              color: Color(0xFF007BA7),
              title: AppLocalizations.of(context)!.help_user_profile_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_user_profile_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.support_agent,
              color: Color(0xFFD4AF37),
              title: AppLocalizations.of(context)!.help_support_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_support_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),

            _buildSectionContainer(
              context: context,
              icon: Icons.build_circle,
              color: Color(0xFF00A86B),
              title: AppLocalizations.of(context)!.help_device_service_title,
              body: [
                Text(
                  AppLocalizations.of(context)!.help_device_service_body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
