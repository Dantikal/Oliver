import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/feedback.dart';
import '../auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});
  final String? email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .forgotPassword(_email.text);
      if (mounted) setState(() => _sent = true);
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
      title: context.tr('forgotTitle'),
      subtitle: context.tr('forgotSub'),
      showBack: true,
      logoSize: 52,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _sent
            ? Column(
                key: const ValueKey('sent'),
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                        gradient: AppColors.forestGradient,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.mark_email_read_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(context.tr('checkEmail'),
                      style: context.text.headlineSmall),
                  const SizedBox(height: 8),
                  Text('${context.tr('resetSent')} ${_email.text}',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium
                          ?.copyWith(color: p.textSecondary)),
                  const SizedBox(height: 22),
                  AppButton(
                      label: context.tr('backToLogin'),
                      onPressed: () => context.pop()),
                ],
              )
            : Form(
                key: _form,
                child: Column(
                  key: const ValueKey('form'),
                  children: [
                    AppTextField(
                      controller: _email,
                      label: context.tr('email'),
                      hint: 'name@mail.com',
                      prefixIcon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email(context),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                        label: context.tr('sendLink'),
                        loading: _loading,
                        onPressed: _submit,
                        icon: Icons.send_rounded),
                  ],
                ),
              ),
      ),
    );
  }
}
