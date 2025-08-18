import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/providers/settings_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    List<String>? bulletPoints,
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
            // Header with icon and title
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
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Content
            Text(
              content,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
              textAlign: TextAlign.justify,
            ),

            // Bullet points if provided
            if (bulletPoints != null) ...[
              SizedBox(height: 12),
              ...bulletPoints.map(
                (point) => Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.fiber_manual_record, size: 8, color: color),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          point,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 13, height: 1.4),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
                children: [
                  // Left side - Back button and title
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
                        AppLocalizations.of(context)!.about_title,
                        style: theme.appBarTheme.titleTextStyle,
                      ),
                    ],
                  ),

                  // Right side - Logo
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Image.asset(
                          'assets/logouzita.png',
                          height: screenHeight * 0.08,
                          width: screenHeight * 0.08,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection:
            Provider.of<SettingsProvider>(
                  context,
                  listen: false,
                ).selectedLanguage ==
                'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section with company logo
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Company logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Color(0xFF007BA7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.business,
                        color: Color(0xFF007BA7),
                        size: 40,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.about_uzita_title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.justify,
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.about_uzita_company,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.about_uzita_description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Company information cards
              _buildInfoCard(
                context: context,
                title: AppLocalizations.of(
                  context,
                )!.about_uzita_introduction_title,
                content: AppLocalizations.of(
                  context,
                )!.about_uzita_introduction_body,
                icon: Icons.info_outline,
                color: Color(0xFF007BA7),
              ),

              _buildInfoCard(
                context: context,
                title: AppLocalizations.of(context)!.about_uzita_mission_title,
                content: AppLocalizations.of(context)!.about_uzita_mission_body,
                icon: Icons.engineering,
                color: Color(0xFF00A86B),
                bulletPoints: [
                  AppLocalizations.of(context)!.about_uzita_auto_doors_title,
                  AppLocalizations.of(context)!.about_uzita_gate_title,
                  AppLocalizations.of(
                    context,
                  )!.about_uzita_automatic_curtain_title,
                  AppLocalizations.of(context)!.about_uzita_smart_lock_title,
                ],
              ),

              _buildInfoCard(
                context: context,
                title: AppLocalizations.of(context)!.about_uzita_vision_title,
                content: AppLocalizations.of(context)!.about_uzita_vision_body,
                icon: Icons.visibility,
                color: Color(0xFFD4AF37),
              ),

              _buildInfoCard(
                context: context,
                title: AppLocalizations.of(
                  context,
                )!.about_uzita_core_values_title,
                content: AppLocalizations.of(
                  context,
                )!.about_uzita_core_values_body,
                icon: Icons.favorite,
                color: Color(0xFF708090),
                bulletPoints: [
                  AppLocalizations.of(
                    context,
                  )!.about_uzita_core_values_bullet_1,
                  AppLocalizations.of(
                    context,
                  )!.about_uzita_core_values_bullet_2,
                  AppLocalizations.of(
                    context,
                  )!.about_uzita_core_values_bullet_3,
                  AppLocalizations.of(
                    context,
                  )!.about_uzita_core_values_bullet_4,
                ],
              ),

              SizedBox(height: 20),

              // Contact information
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF007BA7).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color(0xFF007BA7).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.contact_phone,
                          color: Color(0xFF007BA7),
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.about_uzita_contact_title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007BA7),
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.about_uzita_contact_phone,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          size: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.about_uzita_contact_email,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.about_uzita_contact_address,
                            textAlign: TextAlign.justify,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
