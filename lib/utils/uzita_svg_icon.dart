import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG icons with Material fallbacks on web (avoids vector_graphics decode errors).
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

  static IconData? _materialIconFor(String path) {
    switch (path) {
      case 'assets/icons/user.svg':
      case 'assets/icons/person.svg':
        return Icons.person_outline;
      case 'assets/icons/key.svg':
        return Icons.vpn_key_outlined;
      case 'assets/icons/users.svg':
        return Icons.people_outline;
      case 'assets/icons/report.svg':
        return Icons.assessment_outlined;
      case 'assets/icons/setting.svg':
        return Icons.settings_outlined;
      case 'assets/icons/phone-plus.svg':
        return Icons.phone_android_outlined;
      case 'assets/icons/admin.svg':
        return Icons.admin_panel_settings_outlined;
      case 'assets/icons/office.svg':
        return Icons.business_outlined;
      case 'assets/icons/device.svg':
        return Icons.devices_outlined;
      default:
        return null;
    }
  }

  Color? get _resolvedColor {
    if (color != null) return color;
    return const Color.fromARGB(255, 80, 77, 77);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final IconData? iconData = _materialIconFor(assetPath);
      if (iconData != null) {
        return Icon(
          iconData,
          size: width,
          color: _resolvedColor,
        );
      }
    }

    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
      colorFilter: colorFilter,
      color: color,
    );
  }
}
