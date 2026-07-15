import 'package:flutter/material.dart';
import '../../core/theme/app_input_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autofocus;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  }) : assert(
         !obscureText || maxLines == 1,
         'obscureText kullanılan alanlarda maxLines 1 olmalıdır.',
       );

  @override
  Widget build(BuildContext context) {
    final iconColor = AppInputTheme.iconColor(enabled: enabled);

    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppInputTheme.fillColor(enabled: enabled),
        contentPadding: AppInputTheme.contentPadding,
        labelStyle: AppInputTheme.labelStyle(enabled: enabled),
        hintStyle: AppInputTheme.hintStyle,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: iconColor),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: enabled ? onSuffixIconPressed : null,
                icon: Icon(suffixIcon, color: iconColor),
              ),
        enabledBorder: AppInputTheme.enabledBorder(),
        focusedBorder: AppInputTheme.focusedBorder(),
        errorBorder: AppInputTheme.errorBorder(),
        focusedErrorBorder: AppInputTheme.focusedErrorBorder(),
        disabledBorder: AppInputTheme.disabledBorder(),
      ),
    );
  }
}
