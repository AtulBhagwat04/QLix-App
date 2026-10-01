import 'package:client/core/constants/app_colors.dart';
import 'package:client/core/utils/platform_utils.dart';
import 'package:flutter/material.dart';

class WebSideNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final List<WebSideNavItem> items;

  const WebSideNav({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpanded =
        MediaQuery.sizeOf(context).width >= PlatformUtils.desktopBreakpoint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: isExpanded ? 220 : 72,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Brand Header ────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 20 : 12,
                vertical: 20,
              ),
              child: Row(
                mainAxisAlignment: isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Q',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(width: 12),
                    Text(
                      'QLix',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Navigation Items ────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = index == currentIndex;

                  return _NavItem(
                    icon: isActive ? item.activeIcon : item.icon,
                    label: item.label,
                    isActive: isActive,
                    isExpanded: isExpanded,
                    isDark: isDark,
                    onTap: () => onTabChanged(index),
                  );
                },
              ),
            ),

            // ── Bottom Branding ────────────────────────────────
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'QLix v1.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Data class representing a single side navigation item.
class WebSideNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const WebSideNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Internal widget for a single navigation item.
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isExpanded,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isExpanded ? 14 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              gradient: widget.isActive
                  ? const LinearGradient(
                      colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
                    )
                  : null,
              color: !widget.isActive && _hovering
                  ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF8FAFC))
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: widget.isActive
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: widget.isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 22,
                  color: widget.isActive
                      ? AppColors.primary
                      : (widget.isDark ? Colors.white54 : Colors.grey.shade500),
                ),
                if (widget.isExpanded) ...[
                  const SizedBox(width: 14),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: widget.isActive
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: widget.isActive
                          ? AppColors.primary
                          : (widget.isDark
                                ? Colors.white70
                                : AppColors.textSecondaryLight),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
