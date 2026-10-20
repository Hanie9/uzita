import 'package:flutter/material.dart';
import 'package:uzita/services.dart';
import 'package:uzita/widgets/technician_task_filter_menu.dart';

class TechnicianSearchFilterCard extends StatelessWidget {
  const TechnicianSearchFilterCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.hintText,
    required this.clearTooltip,
    required this.filterValue,
    required this.options,
    required this.onQueryChanged,
    required this.onClear,
    required this.onFilterChanged,
    required this.onDismissFocus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final String hintText;
  final String clearTooltip;
  final String filterValue;
  final List<TechnicianTaskFilterOption> options;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onDismissFocus;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : AppColors.lapisLazuli.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!
              : AppColors.lapisLazuli.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            onTapOutside: (_) => onDismissFocus(),
            onEditingComplete: onDismissFocus,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.lapisLazuli,
                size: 22,
              ),
              suffixIcon: query.trim().isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      tooltip: clearTooltip,
                      onPressed: onClear,
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.lapisLazuli.withValues(alpha: 0.1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.lapisLazuli.withValues(
                  alpha: isDark ? 0.16 : 0.08,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: options.map((TechnicianTaskFilterOption option) {
                  final bool selected = option.value == filterValue;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: selected
                            ? AppColors.lapisLazuli
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            onDismissFocus();
                            if (!selected) onFilterChanged(option.value);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            child: Text(
                              option.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.25,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
