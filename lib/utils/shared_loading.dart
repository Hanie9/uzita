import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/ui_scale.dart';

class SharedLoading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SharedLoading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;
    final defaultSubtitle = subtitle ?? localizations.sharedload_please_wait;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(ui.scale(base: 18, min: 14, max: 24)),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.lapisLazuli.withValues(alpha: 0.1)
                : AppColors.lapisLazuli.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.lapisLazuli.withValues(alpha: 0.2),
              width: ui.scale(base: 2, min: 1.5, max: 2.5),
            ),
          ),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.lapisLazuli),
            strokeWidth: ui.scale(base: 3, min: 2.5, max: 3.5),
          ),
        ),
        SizedBox(height: ui.scale(base: 20, min: 16, max: 26)),
        Text(
          title,
          style: TextStyle(
            color: AppColors.lapisLazuli,
            fontSize: ui.scale(base: 16, min: 14, max: 18),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: ui.scale(base: 8, min: 6, max: 10)),
        Text(
          defaultSubtitle,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: ui.scale(base: 14, min: 12, max: 16),
          ),
        ),
      ],
    );
  }
}
