import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

/// Standardized text input field with unified borders, padding, and icons.
class QlixTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final int maxLines;
  final FocusNode? focusNode;
  final TextStyle? style;
  final TextAlign textAlign;

  const QlixTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffix,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.maxLines = 1,
    this.focusNode,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  State<QlixTextField> createState() => _QlixTextFieldState();
}

class _QlixTextFieldState extends State<QlixTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffixWidget = widget.suffix;

    if (widget.isPassword && suffixWidget == null) {
      suffixWidget = IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppColors.textPlaceholder,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      textAlign: widget.textAlign,
      style: widget.style ?? AppTextStyles.inputTextStyle,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        hintStyle: AppTextStyles.inputHintStyle,
        prefixIcon: widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                color: AppColors.primary,
                size: 20,
              )
            : null,
        suffixIcon: suffixWidget,
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusInput),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusInput),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusInput),
        ),
      ),
    );
  }
}
