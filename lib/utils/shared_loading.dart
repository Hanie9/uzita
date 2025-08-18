import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';

class SharedLoading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SharedLoading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context)!;
    final defaultSubtitle = subtitle ?? localizations.sharedload_please_wait;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.lapisLazuli.withValues(alpha: 0.1)
                : AppColors.lapisLazuli.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.lapisLazuli.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.lapisLazuli),
            strokeWidth: 3,
          ),
        ),
        SizedBox(height: 24),
        Text(
          title,
          style: TextStyle(
            color: AppColors.lapisLazuli,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          defaultSubtitle,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
