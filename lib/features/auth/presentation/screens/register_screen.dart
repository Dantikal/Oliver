import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/feedback.dart';
import '../auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_phone, _email, _name, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _backToLogin() =>
      context.canPop() ? context.pop() : context.go('/login');

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            phone: KgPhoneFormatter.toFull(_phone.text),
            email: _email.text,
            fullName: _name.text,
            password: _password.text,
            confirmPassword: _confirm.text,
          );
      if (!mounted) return;
      context.showSnack(context.tr('registered'), type: SnackType.success);
      _backToLogin();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AuthScaffold(
      title: context.tr('createAccount'),
      subtitle: context.tr('registerSub'),
      showBack: true,
      logoSize: 52,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _phone,
              label: context.tr('phone'),
              prefixText: '+996 ',
              hint: '700 123 456',
              keyboardType: TextInputType.phone,
              inputFormatters: [KgPhoneFormatter()],
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              validator: Validators.phone(context),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _email,
              label: context.tr('email'),
              hint: 'name@mail.com',
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: Validators.email(context),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _name,
              label: context.tr('fullName'),
              hint: context.tr('fullNameHint'),
              prefixIcon: Icons.person_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.fullName(context),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _password,
              label: context.tr('password'),
              hint: '••••••••',
              prefixIcon: Icons.lock_rounded,
              obscure: true,
              textInputAction: TextInputAction.next,
              validator: Validators.passwordStrong(context),
            ),
            const SizedBox(height: 10),
            _PasswordStrength(password: _password.text),
            const SizedBox(height: 14),
            AppTextField(
              controller: _confirm,
              label: context.tr('confirmPassword'),
              hint: '••••••••',
              prefixIcon: Icons.lock_reset_rounded,
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: Validators.confirm(context, () => _password.text),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 22),
            AppButton(
                label: context.tr('register'),
                loading: _loading,
                onPressed: _submit,
                icon: Icons.person_add_alt_1_rounded),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _backToLogin,
              child: Text.rich(
                TextSpan(
                  text: '${context.tr('haveAccount')} ',
                  style:
                      context.text.bodyMedium?.copyWith(color: p.textSecondary),
                  children: [
                    TextSpan(
                      text: context.tr('login'),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rules = [
      (password.length >= 8, context.tr('rule8')),
      (RegExp(r'[A-ZА-ЯЁ]').hasMatch(password), context.tr('ruleUpper')),
      (RegExp(r'\d').hasMatch(password), context.tr('ruleDigit')),
    ];
    final score = rules.where((r) => r.$1).length;
    final color = [
      p.surface3,
      AppColors.danger,
      AppColors.warning,
      AppColors.success
    ][score];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < score ? color : p.surface3,
                    borderRadius: AppRadius.mdAll,
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final (ok, label) in rules)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      ok
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(ok),
                      size: 15,
                      color: ok ? AppColors.success : p.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(label,
                      style: context.text.bodySmall
                          ?.copyWith(color: ok ? p.text : p.textTertiary)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
