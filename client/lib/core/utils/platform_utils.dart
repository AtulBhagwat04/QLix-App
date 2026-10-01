import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Platform and responsive layout utilities.
///
/// Provides breakpoint detection and platform-aware helpers
/// for building adaptive layouts across mobile, tablet, and desktop/web.
class PlatformUtils {
  PlatformUtils._();

  /// True when running in a web browser.
  static bool get isWeb => kIsWeb;

  // ── Breakpoints ────────────────────────────────────────────────
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double wideDesktopBreakpoint = 1600;

  /// Maximum content width for web layouts (prevents ultra-wide stretching).
  static const double maxContentWidth = 1280;

  /// Maximum content width for form / card based pages.
  static const double maxFormContentWidth = 520;

  // ── Device-class checks ────────────────────────────────────────
  static bool isMobileWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTabletWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreakpoint && w < desktopBreakpoint;
  }

  static bool isDesktopWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// True when the layout should use a web/desktop shell (side nav, wider padding).
  /// On web, this kicks in at the tablet breakpoint so wider tablet
  /// browser windows also get the enhanced layout.
  static bool shouldUseWebLayout(BuildContext context) {
    if (!isWeb) return false;
    return MediaQuery.sizeOf(context).width >= tabletBreakpoint;
  }

  /// Returns the appropriate horizontal padding for web content areas.
  static double webContentPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= wideDesktopBreakpoint) return 64;
    if (w >= desktopBreakpoint) return 48;
    if (w >= tabletBreakpoint) return 32;
    return 24;
  }
}
