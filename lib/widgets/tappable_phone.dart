import 'package:flutter/material.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/phone_utils.dart';

/// Displays a phone number; tap dials, long-press copies.
class TappablePhone extends StatelessWidget {
  const TappablePhone({
    super.key,
    required this.phone,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
    this.showIcon = false,
    this.iconSize = 16,
  });

  final String phone;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool showIcon;
  final double iconSize;

  bool get _active => isCallablePhone(phone);

  @override
  Widget build(BuildContext context) {
    final TextStyle effectiveStyle =
        (style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .copyWith(
              color: _active
                  ? (style?.color ?? AppColors.lapisLazuli)
                  : style?.color,
              decoration: _active ? TextDecoration.underline : null,
              decorationColor: _active
                  ? (style?.color ?? AppColors.lapisLazuli)
                  : null,
            );

    final Widget text = Text(
      phone,
      style: effectiveStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );

    if (!_active) return text;

    final Widget content = showIcon
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone,
                size: iconSize,
                color: effectiveStyle.color ?? AppColors.lapisLazuli,
              ),
              const SizedBox(width: 6),
              Flexible(child: text),
            ],
          )
        : text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => launchPhoneCall(context, phone),
      onLongPress: () => copyPhoneToClipboard(context, phone),
      child: content,
    );
  }
}
