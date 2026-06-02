import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'uzita_svg_icon_mapping.dart';

/// Web: render SVG natively to preserve original colors.
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

  static int _viewFactoryId = 0;

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

    const Set<String> mappedFallbackOnlyAssets = <String>{
      'assets/icons/users.svg',
      'assets/icons/report.svg',
      'assets/icons/setting.svg',
    };
    if (mappedFallbackOnlyAssets.contains(normalizedPath)) {
      return Icon(
        UzitaSvgIconMapping.iconForAsset(normalizedPath),
        size: width,
        color: Theme.of(context).iconTheme.color,
      );
    }

    final String viewType = 'uzita-svg-${_viewFactoryId++}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final html.ImageElement image =
          html.ImageElement()
            ..src = normalizedPath
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'contain';
      return image;
    });

    return SizedBox(
      width: width,
      height: height,
      child: HtmlElementView(viewType: viewType),
    );
  }
}
