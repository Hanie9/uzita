import 'package:flutter/material.dart';

/// Maps SVG asset paths to Material icons (used on web instead of flutter_svg).
class UzitaSvgIconMapping {
  UzitaSvgIconMapping._();

  static String normalizePath(String path) {
    final normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('assets/')) return normalized;
    final name = normalized.split('/').last;
    return 'assets/icons/$name';
  }

  static IconData iconForAsset(String path) {
    switch (normalizePath(path)) {
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
        return Icons.image_outlined;
    }
  }
}
