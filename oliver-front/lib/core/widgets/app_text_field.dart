import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../theme/app_colors.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
    this.prefixText,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(widget.label!,
                style:
                    context.text.labelMedium?.copyWith(color: p.textSecondary)),
          ),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textCapitalization: widget.textCapitalization,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: p.textTertiary, size: 21)
                : null,
            prefixText: widget.prefixText,
            prefixStyle:
                context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Icon(
                        _obscured
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        key: ValueKey(_obscured),
                        color: p.textTertiary,
                      ),
                    ),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }
}

/// Поле-выбор (открывает bottom sheet), визуально как текстовое поле.
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    this.label,
    required this.placeholder,
    this.value,
    this.onTap,
    this.icon,
    this.errorText,
    this.enabled = true,
  });

  final String? label;
  final String placeholder;
  final String? value;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label!,
                style:
                    context.text.labelMedium?.copyWith(color: p.textSecondary)),
          ),
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: p.surface2,
            borderRadius: AppRadius.mdAll,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: enabled ? onTap : null,
              child: Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.mdAll,
                  border: hasError
                      ? Border.all(
                          color: Theme.of(context).colorScheme.error,
                          width: 1.2)
                      : null,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 21, color: p.textTertiary),
                      const SizedBox(width: 12)
                    ],
                    Expanded(
                      child: Text(
                        value ?? placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(
                          fontWeight:
                              value != null ? FontWeight.w600 : FontWeight.w500,
                          color: value != null ? p.text : p.textTertiary,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: p.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(errorText!,
                style: Theme.of(context).inputDecorationTheme.errorStyle),
          ),
      ],
    );
  }
}
