import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Mobile/desktop implementation using flutter_svg.
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
    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
      colorFilter: colorFilter ??
          (color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null),
    );
  }
}
