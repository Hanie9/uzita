import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ScreenSizeClass { compact, medium, expanded }

/// Breakpoints for PWA / web and large tablets.
class ResponsiveLayout {
  ResponsiveLayout(this.width);

  final double width;

  factory ResponsiveLayout.of(BuildContext context) {
    return ResponsiveLayout(MediaQuery.sizeOf(context).width);
  }

  ScreenSizeClass get sizeClass {
    if (width < 600) return ScreenSizeClass.compact;
    if (width < 1024) return ScreenSizeClass.medium;
    return ScreenSizeClass.expanded;
  }

  bool get isCompact => sizeClass == ScreenSizeClass.compact;
  bool get isMediumOrWider =>
      sizeClass == ScreenSizeClass.medium ||
      sizeClass == ScreenSizeClass.expanded;

  /// Max width for authenticated app screens on web.
  double get appMaxWidth {
    switch (sizeClass) {
      case ScreenSizeClass.compact:
        return width;
      case ScreenSizeClass.medium:
        return 720;
      case ScreenSizeClass.expanded:
        return 960;
    }
  }

  /// Login / register forms.
  double get authFormMaxWidth {
    switch (sizeClass) {
      case ScreenSizeClass.compact:
        return 520;
      case ScreenSizeClass.medium:
        return 560;
      case ScreenSizeClass.expanded:
        return 600;
    }
  }

  EdgeInsets get pagePadding {
    switch (sizeClass) {
      case ScreenSizeClass.compact:
        return const EdgeInsets.symmetric(horizontal: 16);
      case ScreenSizeClass.medium:
        return const EdgeInsets.symmetric(horizontal: 28);
      case ScreenSizeClass.expanded:
        return const EdgeInsets.symmetric(horizontal: 40);
    }
  }
}

/// Centers the whole app on wide web viewports (phone-like column on desktop).
class PwaResponsiveShell extends StatelessWidget {
  const PwaResponsiveShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final ResponsiveLayout layout = ResponsiveLayout.of(context);
    if (layout.isCompact) return child;

    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color outerBg = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFE8EEF2);

    return ColoredBox(
      color: outerBg,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.appMaxWidth),
          child: Material(
            elevation: layout.sizeClass == ScreenSizeClass.expanded ? 8 : 4,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            color: theme.scaffoldBackgroundColor,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Wraps auth forms (login/register) with responsive width and card on wide screens.
class ResponsiveAuthBody extends StatelessWidget {
  const ResponsiveAuthBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ResponsiveLayout layout = ResponsiveLayout.of(context);
    final double minHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.of(context).padding.vertical;

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: layout.authFormMaxWidth,
        minHeight: layout.isMediumOrWider ? minHeight * 0.85 : 0,
      ),
      child: child,
    );

    if (kIsWeb && layout.isMediumOrWider) {
      content = Card(
        elevation: 6,
        margin: layout.pagePadding.add(const EdgeInsets.symmetric(vertical: 24)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: content,
        ),
      );
    }

    return Center(child: content);
  }
}
