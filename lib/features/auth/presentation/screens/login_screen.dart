import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/feedback.dart';
import '../auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email =
      TextEditingController(text: AppConfig.useMock ? 'azamat@oliver.kg' : '');
  final _password =
      TextEditingController(text: AppConfig.useMock ? 'Oliver2026' : '');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessionId = await ref
          .read(authControllerProvider.notifier)
          .login(_email.text, _password.text);
      if (!mounted) return;
      context.push('/otp',
          extra: {'sessionId': sessionId, 'email': _email.text.trim()});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(context, e));
      context.showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AuthScaffold(
      title: context.tr('welcomeBack'),
      subtitle: context.tr('loginSub'),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _email,
                label: context.tr('email'),
                hint: 'name@mail.com',
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email(context),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _password,
                label: context.tr('password'),
                hint: '••••••••',
                prefixIcon: Icons.lock_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.passwordLogin(context),
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      context.push('/forgot', extra: _email.text.trim()),
                  child: Text(context.tr('forgotPassword'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: _error == null
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!,
                                  style: context.text.bodyMedium?.copyWith(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
              ),
              AppButton(
                  label: context.tr('login'),
                  loading: _loading,
                  onPressed: _submit,
                  icon: Icons.arrow_forward_rounded),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Divider(color: p.surface3)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child:
                        Text(context.tr('or'), style: context.text.bodySmall),
                  ),
                  Expanded(child: Divider(color: p.surface3)),
                ],
              ),
              const SizedBox(height: 18),
              AppButton(
                label: context.tr('register'),
                variant: AppButtonVariant.outline,
                onPressed: () => context.push('/register'),
              ),
              if (AppConfig.useMock) ...[
                const SizedBox(height: 14),
                Text('Demo: код 2FA — 123456',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: p.textTertiary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
