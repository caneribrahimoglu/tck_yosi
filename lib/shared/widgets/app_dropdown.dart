import 'package:flutter/material.dart';

import '../../core/theme/app_input_theme.dart';

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final bool enabled;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;

  const AppDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.prefixIcon,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = AppInputTheme.iconColor(enabled: enabled);

    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
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
        enabledBorder: AppInputTheme.enabledBorder(),
        focusedBorder: AppInputTheme.focusedBorder(),
        errorBorder: AppInputTheme.errorBorder(),
        focusedErrorBorder: AppInputTheme.focusedErrorBorder(),
        disabledBorder: AppInputTheme.disabledBorder(),
      ),
    );
  }
}
