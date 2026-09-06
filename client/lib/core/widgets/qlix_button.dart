import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import 'animated_scale_button.dart';

enum QlixButtonVariant { primary, secondary, outline, text }

/// Standardized solid button component for QLix across the entire application.
class QlixButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final QlixButtonVariant variant;
  final double? width;
  final double height;
  final double borderRadius;
  final List<Color>? gradientColors;
  final Color? backgroundColor;
  final Color? textColor;

  const QlixButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = QlixButtonVariant.primary,
    this.width,
    this.height = 48.0,
    this.borderRadius = AppSizes.radiusButton,
    this.gradientColors,
    this.backgroundColor,
    this.textColor,
  });

  /// Primary Solid Action Button (AppColors.primary #6366F1)
  const factory QlixButton.primary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading,
    IconData? icon,
    double? width,
    double height,
    double borderRadius,
    List<Color>? gradientColors,
    Color? backgroundColor,
    Color? textColor,
  }) = _QlixPrimaryButton;

  /// Secondary Tinted Solid Button (#EEF2FF)
  const factory QlixButton.secondary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading,
    IconData? icon,
    double? width,
    double height,
    double borderRadius,
    Color? backgroundColor,
    Color? textColor,
  }) = _QlixSecondaryButton;

  /// Outlined Border Button
  const factory QlixButton.outline({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading,
    IconData? icon,
    double? width,
    double height,
    double borderRadius,
    Color? borderColor,
    Color? textColor,
  }) = _QlixOutlineButton;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == QlixButtonVariant.primary;
    final isSecondary = variant == QlixButtonVariant.secondary;
    final isOutline = variant == QlixButtonVariant.outline;
    final isEnabled = onPressed != null && !isLoading;

    if (isLoading) {
      return SizedBox(
        height: height,
        width: width,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: isPrimary ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      );
    }

    // Determine background color
    Color effectiveBg;
    if (!isEnabled) {
      effectiveBg = const Color(0xFF94A3B8); // Solid disabled gray
    } else if (isPrimary) {
      effectiveBg = backgroundColor ?? AppColors.primary;
    } else if (isSecondary) {
      effectiveBg = backgroundColor ?? AppColors.primarySoft;
    } else if (isOutline) {
      effectiveBg = Colors.transparent;
    } else {
      effectiveBg = backgroundColor ?? Colors.transparent;
    }

    // Determine text color
    Color effectiveFg;
    if (textColor != null) {
      effectiveFg = textColor!;
    } else if (isPrimary || !isEnabled) {
      effectiveFg = Colors.white;
    } else if (isSecondary || isOutline) {
      effectiveFg = AppColors.primary;
    } else {
      effectiveFg = AppColors.textPrimary;
    }

    // Determine border
    Border? effectiveBorder;
    if (isOutline) {
      effectiveBorder = Border.all(
        color: isEnabled
            ? (backgroundColor ?? AppColors.primary)
            : const Color(0xFFCBD5E1),
        width: 1.5,
      );
    }

    // Determine shadow
    List<BoxShadow>? effectiveShadow;
    if (isPrimary && isEnabled && gradientColors == null) {
      effectiveShadow = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    }

    final buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: effectiveFg,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: AppTextStyles.buttonText.copyWith(
            color: effectiveFg,
          ),
        ),
      ],
    );

    return AnimatedScaleButton(
      onPressed: isEnabled ? onPressed : null,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: isPrimary && gradientColors != null && isEnabled
              ? LinearGradient(colors: gradientColors!)
              : null,
          color: (gradientColors == null || !isEnabled) ? effectiveBg : null,
          border: effectiveBorder,
          boxShadow: effectiveShadow,
        ),
        alignment: Alignment.center,
        child: buttonContent,
      ),
    );
  }
}

class _QlixPrimaryButton extends QlixButton {
  const _QlixPrimaryButton({
    super.key,
    required super.text,
    super.onPressed,
    super.isLoading,
    super.icon,
    super.width,
    super.height = 48.0,
    super.borderRadius = AppSizes.radiusButton,
    super.gradientColors,
    super.backgroundColor,
    super.textColor,
  }) : super(variant: QlixButtonVariant.primary);
}

class _QlixSecondaryButton extends QlixButton {
  const _QlixSecondaryButton({
    super.key,
    required super.text,
    super.onPressed,
    super.isLoading,
    super.icon,
    super.width,
    super.height = 48.0,
    super.borderRadius = AppSizes.radiusButton,
    super.backgroundColor,
    super.textColor,
  }) : super(variant: QlixButtonVariant.secondary);
}

class _QlixOutlineButton extends QlixButton {
  const _QlixOutlineButton({
    super.key,
    required super.text,
    super.onPressed,
    super.isLoading,
    super.icon,
    super.width,
    super.height = 48.0,
    super.borderRadius = AppSizes.radiusButton,
    Color? borderColor,
    super.textColor,
  }) : super(variant: QlixButtonVariant.outline, backgroundColor: borderColor);
}
