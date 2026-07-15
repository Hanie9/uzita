import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'uzita_svg_icon_mapping.dart';

/// Web: flutter_svg for full-color assets; Material icons when tinting is requested.
class UzitaSvgIcon extends StatelessWidget {
  const UzitaSvgIcon({
    super.key,
    required this.assetPath,
    this.width = 24,
    this.height = 24,
    this.color,
    this.colorFilter,
  });

  final String assetPath;
  final double width;
  final double height;
  final Color? color;
  final ColorFilter? colorFilter;

  @override
  Widget build(BuildContext context) {
    final String normalizedPath = UzitaSvgIconMapping.normalizePath(assetPath);

    // If caller explicitly requests tinting, keep Material icon fallback.
    if (color != null || colorFilter != null) {
      return Icon(
        UzitaSvgIconMapping.iconForAsset(normalizedPath),
        size: width,
        color: color ?? Theme.of(context).iconTheme.color,
      );
    }

    return SvgPicture.asset(
      normalizedPath,
      width: width,
      height: height,
    );
  }
}
