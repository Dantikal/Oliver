import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/feedback.dart';
import '../auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.sessionId, required this.email});
  final String sessionId;
  final String email;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const _len = 6;
  final _controllers = List.generate(_len, (_) => TextEditingController());
  final _nodes = List.generate(_len, (_) => FocusNode());
  late final _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));
  Timer? _timer;
  int _seconds = AppConfig.resendSeconds;
  bool _loading = false;
  bool _resending = false;
  bool _error = false;

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startTimer();
    for (final n in _nodes) {
      n.addListener(() => setState(() {}));
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nodes.first.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = AppConfig.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 1) t.cancel();
      if (mounted) setState(() => _seconds--);
    });
  }

  void _onChanged(int i, String v) {
    if (_error) setState(() => _error = false);
    // Вставка целого кода из буфера / автозаполнения.
    if (v.length > 1) {
      final digits = v.replaceAll(RegExp(r'\D'), '');
      for (var k = 0; k < _len; k++) {
        _controllers[k].text = k < digits.length ? digits[k] : '';
      }
      final next = digits.length.clamp(0, _len - 1);
      _nodes[next].requestFocus();
    } else if (v.isNotEmpty) {
      HapticFeedback.selectionClick();
      if (i < _len - 1) {
        _nodes[i + 1].requestFocus();
      } else {
        _nodes[i].unfocus();
      }
    }
    setState(() {});
    if (_code.length == _len) _verify();
  }

  KeyEventResult _onKey(int i, KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[i].text.isEmpty &&
        i > 0) {
      _controllers[i - 1].clear();
      _nodes[i - 1].requestFocus();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _verify() async {
    if (_code.length != _len || _loading) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verify2fa(widget.sessionId, _code);
      HapticFeedback.mediumImpact();
      // Редирект на главную выполнит router (status → authenticated).
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = true);
      _shake.forward(from: 0);
      HapticFeedback.heavyImpact();
      context.showError(e);
      for (final c in _controllers) {
        c.clear();
      }
      _nodes.first.requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resend2fa(widget.sessionId);
      if (!mounted) return;
      context.showSnack(context.tr('codeResent'), type: SnackType.success);
      _startTimer();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AuthScaffold(
      title: context.tr('otpTitle'),
      subtitle: '${context.tr('otpSub')} ${widget.email}',
      showBack: true,
      logoSize: 52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) {
              final t = _shake.value;
              final dx = t == 0
                  ? 0.0
                  : 10 * (1 - t) * ((t * 10).floor().isEven ? 1 : -1);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < _len; i++)
                  _OtpCell(
                    controller: _controllers[i],
                    node: _nodes[i],
                    error: _error,
                    onChanged: (v) => _onChanged(i, v),
                    onKey: (e) => _onKey(i, e),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          AppButton(
            label: context.tr('confirm'),
            loading: _loading,
            onPressed: _code.length == _len ? _verify : null,
            icon: Icons.verified_user_rounded,
          ),
          const SizedBox(height: 18),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _seconds > 0
                  ? Row(
                      key: const ValueKey('t'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            value: _seconds / AppConfig.resendSeconds,
                            strokeWidth: 2.6,
                            backgroundColor: p.surface3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${context.tr('resendIn')} 0:${_seconds.toString().padLeft(2, '0')}',
                          style: context.text.bodyMedium?.copyWith(
                              color: p.textSecondary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    )
                  : TextButton.icon(
                      key: const ValueKey('r'),
                      onPressed: _resending ? null : _resend,
                      icon: _resending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded),
                      label: Text(context.tr('resendCode'),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({
    required this.controller,
    required this.node,
    required this.error,
    required this.onChanged,
    required this.onKey,
  });

  final TextEditingController controller;
  final FocusNode node;
  final bool error;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent) onKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final focused = node.hasFocus;
    final filled = controller.text.isNotEmpty;
    final borderColor = error
        ? AppColors.danger
        : (focused
            ? AppColors.primary
            : (filled
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.transparent));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 60,
      decoration: BoxDecoration(
        color: filled ? AppColors.primary.withValues(alpha: 0.08) : p.surface2,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: borderColor, width: focused ? 2 : 1.5),
        boxShadow: focused
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 14)
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Focus(
        onKeyEvent: (_, e) => onKey(e),
        child: TextField(
          controller: controller,
          focusNode: node,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6)
          ],
          showCursor: false,
          style: context.text.headlineMedium?.copyWith(fontSize: 24),
          decoration: const InputDecoration(
            filled: false,
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
