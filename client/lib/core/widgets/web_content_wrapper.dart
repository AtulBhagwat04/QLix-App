import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';

/// Wraps page content with appropriate constraints for web layouts.
///
/// On web/desktop viewports this centers the content and caps the max width
/// so pages don't stretch across ultra-wide monitors. On mobile-width
/// viewports it passes through untouched.
class WebContentWrapper extends StatelessWidget {
  final Widget child;

  /// Maximum width of the content area. Defaults to [PlatformUtils.maxContentWidth].
  final double? maxWidth;

  /// Additional horizontal padding applied inside the constraint box on web.
  final double? horizontalPadding;

  const WebContentWrapper({
    super.key,
    required this.child,
    this.maxWidth,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.shouldUseWebLayout(context)) {
      return child;
    }

    final effectiveMaxWidth = maxWidth ?? PlatformUtils.maxContentWidth;
    final effectivePadding =
        horizontalPadding ?? PlatformUtils.webContentPadding(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: effectivePadding),
          child: child,
        ),
      ),
    );
  }
}
