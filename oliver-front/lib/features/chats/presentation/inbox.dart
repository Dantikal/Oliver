import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/sound/sfx.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/counters_controller.dart';
import '../data/chat_repositories.dart';
import '../domain/chat.dart';
import 'chat_controllers.dart';

/// Чат, который сейчас открыт на экране (для него уведомления не нужны).
final activeChatProvider = StateProvider<String?>((_) => null);

/// Глобальный слушатель: сообщение в чат, который сейчас не открыт, —
/// звук, баннер сверху, счётчики. Живёт, пока пользователь вошёл.
final inboxProvider = Provider<void>((ref) {
  final authed = ref.watch(authControllerProvider
      .select((s) => s.status == AuthStatus.authenticated));
  if (!authed) return;
  final socket = ref.read(chatSocketProvider);
  socket.connect().ignore();
  final sub = socket.events.listen((e) async {
    if (e is! MessageEvent) return;
    final m = e.message;
    final me = ref.read(currentUserProvider)?.id;
    if (m.senderId == me || ref.read(activeChatProvider) == m.chatId) return;
    HapticFeedback.mediumImpact();
    Sfx.notify();
    ref.read(countersProvider.notifier).incMessages();
    // Список чатов грузится лениво — догружаем, чтобы знать собеседника.
    List<ChatSummary> chats;
    try {
      chats = await ref.read(chatListProvider.future);
    } catch (_) {
      return;
    }
    ref
        .read(chatListProvider.notifier)
        .onMessage(m, mine: false, viewing: false);
    final chat = chats.where((c) => c.chatId == m.chatId).firstOrNull;
    if (chat != null) _showBanner(ref, chat.peer, m);
  });
  ref.onDispose(sub.cancel);
});

OverlayEntry? _current;

void _showBanner(Ref ref, User peer, Message m) {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _current?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _MessageBanner(
      peer: peer,
      message: m,
      onOpen: () =>
          ref.read(routerProvider).push('/chat/${m.chatId}', extra: peer),
      onDone: () {
        if (_current == entry) _current = null;
        entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

String _preview(BuildContext c, Message m) => switch (m.type) {
      MessageType.image => '📷 ${c.tr('photo')}',
      MessageType.video => '🎬 ${c.tr('video')}',
      MessageType.voice => '🎙 ${c.tr('voiceMessage')}',
      _ => m.content,
    };

/// Стеклянная плашка сверху: выезжает пружиной, сама уходит через 4 с,
/// смахивается вверх, по тапу открывает чат.
class _MessageBanner extends StatefulWidget {
  const _MessageBanner(
      {required this.peer,
      required this.message,
      required this.onOpen,
      required this.onDone});
  final User peer;
  final Message message;
  final VoidCallback onOpen;
  final VoidCallback onDone;

  @override
  State<_MessageBanner> createState() => _MessageBannerState();
}

class _MessageBannerState extends State<_MessageBanner>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 260));
  Timer? _timer;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(seconds: 4), _close);
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top + 6,
      left: 10,
      right: 10,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = Curves.easeOutBack.transform(_c.value);
          return Transform.translate(
            offset: Offset(0, -120 * (1 - t) + _drag),
            child: Opacity(opacity: _c.value.clamp(0.0, 1.0), child: child),
          );
        },
        child: GestureDetector(
          onTap: () {
            _close();
            widget.onOpen();
          },
          onVerticalDragUpdate: (d) =>
              setState(() => _drag = (_drag + d.delta.dy).clamp(-120, 12)),
          onVerticalDragEnd: (_) {
            if (_drag < -30) {
              _close();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Material(
            type: MaterialType.transparency,
            child: Glass(
              radius: AppRadius.xl,
              blur: 30,
              tint: p.surface.withValues(alpha: context.isDark ? 0.8 : 0.88),
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  AppAvatar(
                      url: widget.peer.avatarUrl,
                      name: widget.peer.fullName,
                      size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(widget.peer.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleSmall),
                            ),
                            Text(context.tr('justNow'),
                                style: context.text.bodySmall
                                    ?.copyWith(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_preview(context, widget.message),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium
                                ?.copyWith(color: p.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: AppColors.lime, shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
