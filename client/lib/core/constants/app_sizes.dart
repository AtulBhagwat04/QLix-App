import 'package:flutter/widgets.dart';

/// Centralized responsive dimensions, percentage calculations, spacing, and radiuses.
class AppSizes {
  // Reference Device Dimensions (standard mobile: 390dp x 844dp)
  static const double baseWidth = 390.0;
  static const double baseHeight = 844.0;

  // -------------------------------------------------------------
  // Dynamic Responsive Percentage Helpers
  // -------------------------------------------------------------
  
  /// Get width by percentage of screen (e.g. AppSizes.widthPct(context, 50) = 50% width)
  static double widthPct(BuildContext context, double percent) =>
      MediaQuery.sizeOf(context).width * (percent / 100.0);

  /// Get height by percentage of screen (e.g. AppSizes.heightPct(context, 30) = 30% height)
  static double heightPct(BuildContext context, double percent) =>
      MediaQuery.sizeOf(context).height * (percent / 100.0);

  /// Proportionally scale a size relative to base width with safety bounds
  static double scale(
    BuildContext context,
    double size, {
    double minScale = 0.8,
    double maxScale = 1.3,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final factor = (screenWidth / baseWidth).clamp(minScale, maxScale);
    return size * factor;
  }

  // -------------------------------------------------------------
  // Device Breakpoints
  // -------------------------------------------------------------
  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  // -------------------------------------------------------------
  // Adaptive Layout Constraints
  // -------------------------------------------------------------
  
  /// Max bounded width for cards and forms (prevents stretching on tablets/desktops)
  static double maxFormWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 480.0;
    return w * 0.92;
  }

  /// Adaptive horizontal padding for pages
  static double pageHorizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return 16.0;
    if (w < 600) return 24.0;
    return 32.0;
  }

  // -------------------------------------------------------------
  // Standard Constant Spacings & Paddings
  // -------------------------------------------------------------
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space18 = 18.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space36 = 36.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // -------------------------------------------------------------
  // Standard Constant Border Radiuses
  // -------------------------------------------------------------
  static const double radiusCard = 15.0;
  static const double radiusInput = 12.0;
  static const double radiusButton = 12.0;
  static const double radiusBadge = 12.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusPill = 100.0;

  // -------------------------------------------------------------
  // Icon & Image Sizes
  // -------------------------------------------------------------
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 40.0;
  static const double logoSize = 64.0;

  // -------------------------------------------------------------
  // Specific Component Dimensions
  // -------------------------------------------------------------
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 38.0;
  static const double buttonHeightLarge = 54.0;
  static const double inputHeight = 52.0;
  static const double barHeight = 4.0;
}

/// Extension on BuildContext for quick and concise responsive sizing calls.
extension ResponsiveContext on BuildContext {
  /// Screen width in logical pixels
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Screen height in logical pixels
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Width percentage (e.g. context.wPct(50) for 50% width)
  double wPct(double percent) => AppSizes.widthPct(this, percent);

  /// Height percentage (e.g. context.hPct(25) for 25% height)
  double hPct(double percent) => AppSizes.heightPct(this, percent);

  /// Scaled size based on screen ratio
  double rSize(double size, {double minScale = 0.8, double maxScale = 1.3}) =>
      AppSizes.scale(this, size, minScale: minScale, maxScale: maxScale);

  /// True if device width < 360dp
  bool get isSmallMobile => AppSizes.isSmallMobile(this);

  /// True if device width < 600dp
  bool get isMobile => AppSizes.isMobile(this);

  /// True if device width >= 600dp
  bool get isTablet => AppSizes.isTablet(this);
}
