import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

enum QlixBadgeType { live, active, draft, ended, approved, pending, info, warning }

/// Standardized status badge chip with automatic styling based on type or state.
class QlixBadge extends StatelessWidget {
  final String text;
  final QlixBadgeType? type;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  const QlixBadge({
    super.key,
    required this.text,
    this.type,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  /// Factory for standard session state strings ('active', 'draft', 'ended')
  factory QlixBadge.fromSessionState(String state) {
    switch (state.toLowerCase()) {
      case 'active':
        return const QlixBadge(
          text: 'ACTIVE',
          type: QlixBadgeType.active,
        );
      case 'draft':
        return const QlixBadge(
          text: 'DRAFT',
          type: QlixBadgeType.draft,
        );
      case 'ended':
        return const QlixBadge(
          text: 'ENDED',
          type: QlixBadgeType.ended,
        );
      default:
        return QlixBadge(text: state.toUpperCase(), type: QlixBadgeType.info);
    }
  }

  /// Factory for glowing LIVE badge with pulsing red indicator
  factory QlixBadge.live({String text = 'LIVE'}) {
    return QlixBadge(
      text: text,
      type: QlixBadgeType.live,
      leading: Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(right: 4),
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    if (type != null) {
      switch (type!) {
        case QlixBadgeType.live:
          bg = AppColors.errorLight;
          fg = AppColors.error;
          border = AppColors.error.withValues(alpha: 0.3);
          break;
        case QlixBadgeType.active:
          bg = AppColors.successLight;
          fg = AppColors.success;
          border = AppColors.success.withValues(alpha: 0.3);
          break;
        case QlixBadgeType.draft:
          bg = const Color(0xFFF1F5F9);
          fg = AppColors.textMuted;
          border = AppColors.border;
          break;
        case QlixBadgeType.ended:
          bg = const Color(0xFFF1F5F9);
          fg = AppColors.textPlaceholder;
          border = AppColors.border;
          break;
        case QlixBadgeType.approved:
          bg = AppColors.successLight;
          fg = AppColors.success;
          border = AppColors.success.withValues(alpha: 0.3);
          break;
        case QlixBadgeType.pending:
          bg = AppColors.warningLight;
          fg = AppColors.warning;
          border = AppColors.warning.withValues(alpha: 0.3);
          break;
        case QlixBadgeType.info:
          bg = AppColors.infoLight;
          fg = AppColors.info;
          border = AppColors.info.withValues(alpha: 0.3);
          break;
        case QlixBadgeType.warning:
          bg = AppColors.warningLight;
          fg = AppColors.warning;
          border = AppColors.warning.withValues(alpha: 0.3);
          break;
      }
    } else {
      bg = backgroundColor ?? AppColors.primarySoft;
      fg = textColor ?? AppColors.primary;
      border = borderColor ?? AppColors.border;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusBadge),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ?leading,
          Text(
            text,
            style: AppTextStyles.badge.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
