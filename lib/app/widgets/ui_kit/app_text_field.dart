import 'package:flutter/material.dart';

import '../../resources/ui_resources.dart';
import '../margin.dart';

/// Поле формы с общей меткой, оформлением и доступной ошибкой.
/// Native TextFormField сохраняет работу клавиатуры, autofill и Form.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(label, style: UITextStyles.semibold13)),
        const Margin.vertical(8),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            validator: validator,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            obscureText: obscureText,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            textCapitalization: TextCapitalization.none,
            style: UITextStyles.regular16,
            cursorColor: UIColors.primary,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            errorBuilder: (context, error) => Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: UITextStyles.regular13.copyWith(color: UIColors.error),
              ),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: UITextStyles.regular16.copyWith(
                color: UIColors.text.withValues(alpha: .45),
              ),
              filled: true,
              fillColor: UIColors.highlightArea,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: border(UIColors.transparent),
              focusedBorder: border(UIColors.primary),
              errorBorder: border(UIColors.error),
              focusedErrorBorder: border(UIColors.error),
              suffixIcon: suffix,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
