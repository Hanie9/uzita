import 'package:flutter/material.dart';

import 'uzita_svg_icon_mapping.dart';

/// Web: Material icons only (no flutter_svg).
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

  Color? _resolvedColor(BuildContext context) {
    if (color != null) return color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey[400] : const Color.fromARGB(255, 80, 77, 77);
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      UzitaSvgIconMapping.iconForAsset(assetPath),
      size: width,
      color: _resolvedColor(context),
    );
  }
}
