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

class TechnicianTaskFilterMenu extends StatefulWidget {
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
  State<TechnicianTaskFilterMenu> createState() =>
      _TechnicianTaskFilterMenuState();
}

class _TechnicianTaskFilterMenuState extends State<TechnicianTaskFilterMenu>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _selectOption(String optionValue) {
    if (optionValue != widget.value) {
      widget.onChanged(optionValue);
    }
    if (_expanded) {
      _toggleExpanded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final TechnicianTaskFilterOption selected = widget.options.firstWhere(
      (TechnicianTaskFilterOption option) => option.value == widget.value,
      orElse: () => widget.options.first,
    );

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? AppColors.lapisLazuli.withValues(alpha: 0.28)
                : AppColors.lapisLazuli.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.lapisLazuli.withValues(
                alpha: _expanded ? 0.1 : 0.05,
              ),
              blurRadius: _expanded ? 14 : 8,
              offset: Offset(0, _expanded ? 4 : 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: _toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.65),
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
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.5).animate(
                        _expandAnimation,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.lapisLazuli.withValues(alpha: 0.1),
                  ),
                  ...widget.options.map((TechnicianTaskFilterOption option) {
                    final bool isSelected = option.value == widget.value;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectOption(option.value),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.lapisLazuli.withValues(alpha: 0.08)
                                : Colors.transparent,
                            border: Border(
                              bottom: option == widget.options.last
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: AppColors.lapisLazuli.withValues(
                                        alpha: 0.06,
                                      ),
                                    ),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 20,
                                color: isSelected
                                    ? AppColors.lapisLazuli
                                    : theme.textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.lapisLazuli
                                        : theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: AppColors.lapisLazuli,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
