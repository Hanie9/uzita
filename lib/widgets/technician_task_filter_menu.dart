import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';

class TechnicianTaskFilterOption {
  const TechnicianTaskFilterOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class TechnicianTaskFilterMenu extends StatelessWidget {
  const TechnicianTaskFilterMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<TechnicianTaskFilterOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final TechnicianTaskFilterOption selected = options.firstWhere(
      (TechnicianTaskFilterOption option) => option.value == value,
      orElse: () => options.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.lapisLazuli.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lapisLazuli.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        initialValue: value,
        onSelected: onChanged,
        offset: const Offset(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        itemBuilder: (BuildContext context) {
          return options
              .map(
                (TechnicianTaskFilterOption option) => PopupMenuItem<String>(
                  value: option.value,
                  child: Row(
                    children: <Widget>[
                      if (option.value == value) ...<Widget>[
                        const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.lapisLazuli,
                        ),
                        const SizedBox(width: 8),
                      ] else
                        const SizedBox(width: 26),
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontWeight: option.value == value
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lapisLazuli.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: AppColors.lapisLazuli,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      loc.tech_filter_status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
