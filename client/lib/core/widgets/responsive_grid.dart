import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';

/// A responsive grid that adapts its cross-axis count based on screen width.
///
/// On mobile it defaults to [mobileCrossAxisCount] columns, on tablet to
/// [tabletCrossAxisCount], and on desktop to [desktopCrossAxisCount].
/// Falls back to a standard [GridView.count] with the calculated column count.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;

  /// Number of columns on mobile (<600dp). Defaults to 2.
  final int mobileCrossAxisCount;

  /// Number of columns on tablet (600–1200dp). Defaults to 3.
  final int tabletCrossAxisCount;

  /// Number of columns on desktop (≥1200dp). Defaults to 4.
  final int desktopCrossAxisCount;

  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileCrossAxisCount = 2,
    this.tabletCrossAxisCount = 3,
    this.desktopCrossAxisCount = 4,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 1.4,
    this.shrinkWrap = true,
    this.physics,
  });

  int _crossAxisCount(BuildContext context) {
    if (PlatformUtils.isDesktopWidth(context)) return desktopCrossAxisCount;
    if (PlatformUtils.isTabletWidth(context)) return tabletCrossAxisCount;
    return mobileCrossAxisCount;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: _crossAxisCount(context),
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
