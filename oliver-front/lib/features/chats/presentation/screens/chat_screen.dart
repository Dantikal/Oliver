import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/skeletons.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../catalog/presentation/widgets/media_gallery.dart';
import '../../domain/chat.dart';
import '../chat_controllers.dart';
import '../widgets/message_status_icon.dart';
import '../widgets/voice.dart';
import '../inbox.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId, this.peer});
  final String chatId;
  final User? peer;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _emoji = false;
  bool _recording = false;
  Timer? _typingTimer;

  late final _active = ref.read(activeChatProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Пока чат открыт, уведомления о нём не показываем.
    Future.microtask(() => _active.state = widget.chatId);
    _focus.addListener(() {
      if (_focus.hasFocus && _emoji) setState(() => _emoji = false);
    });
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    final active = _active;
    final id = widget.chatId;
    Future.microtask(() {
      if (active.state == id) active.state = null;
    });
    _typingTimer?.cancel();
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatRoomController get _ctrl =>
      ref.read(chatRoomProvider(widget.chatId).notifier);

  void _onChanged(String _) {
    if (_typingTimer == null) _ctrl.typing(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _ctrl.typing(false);
      _typingTimer = null;
    });
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    HapticFeedback.lightImpact();
    _ctrl.sendText(t);
    _text.clear();
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final (i, icon, label, g) in [
                (
                  0,
                  Icons.photo_rounded,
                  ctx.tr('photo'),
                  AppColors.brandGradient
                ),
                (
                  1,
                  Icons.photo_camera_rounded,
                  ctx.tr('camera'),
                  AppColors.leafGradient
                ),
                (
                  2,
                  Icons.videocam_rounded,
                  ctx.tr('video'),
                  AppColors.forestGradient
                ),
              ])
                Pressable(
                  onTap: () => Navigator.pop(ctx, i),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                            gradient: g, borderRadius: AppRadius.mdAll),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(label, style: ctx.text.labelMedium),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    final picker = ImagePicker();
    try {
      final XFile? f = switch (choice) {
        0 => await picker.pickImage(
            source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000),
        1 => await picker.pickImage(
            source: ImageSource.camera, imageQuality: 85, maxWidth: 2000),
        _ => await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 1)),
      };
      if (f != null) {
        _ctrl.sendMedia(
            f.path, choice == 2 ? MessageType.video : MessageType.image);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        context.showSnack(e.message ?? context.tr('errGeneric'),
            type: SnackType.error);
      }
    }
  }

  void _startVoice() {
    _focus.unfocus();
    setState(() {
      _emoji = false;
      _recording = true;
    });
  }

  void _sendVoice(String path, int seconds) {
    setState(() => _recording = false);
    _ctrl.sendMedia(path, MessageType.voice, content: '$seconds');
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _toggleEmoji() {
    HapticFeedback.selectionClick();
    if (_emoji) {
      _focus.requestFocus();
    } else {
      _focus.unfocus();
    }
    setState(() => _emoji = !_emoji);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = ref.watch(chatRoomProvider(widget.chatId));
    final me = ref.watch(currentUserProvider)?.id;
    final chat = ref.watch(chatListProvider.select((s) =>
        s.valueOrNull?.where((c) => c.chatId == widget.chatId).firstOrNull));
    final peer = widget.peer ?? chat?.peer;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 64,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop()),
        title: GestureDetector(
          onTap: peer == null
              ? null
              : () => context.push('/user/${peer.id}', extra: peer),
          child: Row(
            children: [
              AppAvatar(
                  url: peer?.avatarUrl,
                  name: peer?.fullName ?? '',
                  size: 42,
                  online: chat?.isOnline ?? false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(peer?.fullName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        state.peerTyping
                            ? context.tr('typing')
                            : (chat?.isOnline ?? false)
                                ? context.tr('online')
                                : context.tr('recently'),
                        key: ValueKey(state.peerTyping),
                        style: context.text.bodySmall?.copyWith(
                          color: state.peerTyping || (chat?.isOnline ?? false)
                              ? AppColors.primary
                              : p.textTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () => context.showSnack(context.tr('soon')),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          if (chat?.productTitle != null)
            Pressable(
              scale: 0.98,
              onTap: () => context.push('/product/${chat.productId}'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: p.border)),
                child: Row(
                  children: [
                    AppImage(chat!.productImage,
                        width: 42, height: 42, radius: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(chat.productTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.textTertiary),
                  ],
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _focus.unfocus();
                if (_emoji) setState(() => _emoji = false);
              },
              child: _MessagesList(
                state: state,
                myId: me,
                scroll: _scroll,
                onLoadMore: _ctrl.loadMore,
                onRetry: _ctrl.retry,
                onReload: _ctrl.load,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
                      .animate(a),
                  child: c),
            ),
            child: _recording
                ? VoiceRecorderBar(
                    key: const ValueKey('rec'),
                    onCancel: () => setState(() => _recording = false),
                    onSend: _sendVoice,
                  )
                : _Composer(
                    key: const ValueKey('composer'),
                    controller: _text,
                    focusNode: _focus,
                    emojiOpen: _emoji,
                    onChanged: _onChanged,
                    onSend: _send,
                    onAttach: _attach,
                    onEmoji: _toggleEmoji,
                    onMic: _startVoice,
                  ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _emoji
                ? SizedBox(
                    height: 290,
                    child: EmojiPicker(
                      textEditingController: _text,
                      config: Config(
                        height: 290,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          backgroundColor: p.surface,
                          columns: 8,
                          emojiSizeMax: 28,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor: p.surface,
                          indicatorColor: AppColors.primary,
                          iconColorSelected: AppColors.primary,
                          iconColor: p.textTertiary,
                        ),
                        bottomActionBarConfig:
                            const BottomActionBarConfig(enabled: false),
                        searchViewConfig:
                            SearchViewConfig(backgroundColor: p.surface),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.state,
    required this.myId,
    required this.scroll,
    required this.onLoadMore,
    required this.onRetry,
    required this.onReload,
  });

  final ChatRoomState state;
  final String? myId;
  final ScrollController scroll;
  final VoidCallback onLoadMore;
  final void Function(Message) onRetry;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.messages.isEmpty) {
      return ListView(
        reverse: true,
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 8; i++)
            Align(
              alignment:
                  i.isEven ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: ShimmerWrap(
                    child: Bone(
                        width: 120.0 + (i * 37) % 120, height: 42, radius: 20)),
              ),
            ),
        ],
      );
    }
    if (state.error != null && state.messages.isEmpty) {
      return Center(child: ErrorView(error: state.error, onRetry: onReload));
    }
    if (state.messages.isEmpty && !state.peerTyping) {
      return Center(
        child: EmptyState(
            icon: Icons.waving_hand_outlined,
            title: context.tr('sayHi'),
            subtitle: context.tr('sayHiSub')),
      );
    }

    final msgs = state.messages;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) onLoadMore();
        return false;
      },
      child: ListView.builder(
        controller: scroll,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: msgs.length +
            (state.peerTyping ? 1 : 0) +
            (state.loadingMore ? 1 : 0),
        itemBuilder: (_, rawIndex) {
          if (state.peerTyping && rawIndex == 0) return const _TypingBubble();
          final i = rawIndex - (state.peerTyping ? 1 : 0);
          if (i >= msgs.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4))),
            );
          }
          final m = msgs[i];
          final older = i + 1 < msgs.length ? msgs[i + 1] : null;
          final newer = i > 0 ? msgs[i - 1] : null;
          final showDate =
              older == null || !isSameDay(older.createdAt, m.createdAt);
          final groupedWithNewer = newer != null &&
              newer.senderId == m.senderId &&
              isSameDay(newer.createdAt, m.createdAt);
          return Column(
            children: [
              if (showDate) _DateChip(date: m.createdAt),
              _Bubble(
                message: m,
                mine: m.senderId == myId,
                tail: !groupedWithNewer,
                onRetry: () => onRetry(m),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: context.palette.surface2, borderRadius: AppRadius.mdAll),
          child: Text(formatDayHeader(context, date),
              style: context.text.labelSmall
                  ?.copyWith(color: context.palette.textSecondary)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {required this.message,
      required this.mine,
      required this.tail,
      required this.onRetry});
  final Message message;
  final bool mine;
  final bool tail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = message;
    const r = Radius.circular(20);
    const small = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: mine || !tail ? r : small,
      bottomRight: mine && tail ? small : r,
    );
    final isMedia = m.type == MessageType.image || m.type == MessageType.video;
    final timeRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatClock(m.createdAt),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: mine || isMedia
                  ? Colors.white.withValues(alpha: 0.8)
                  : p.textTertiary,
            )),
        if (mine) ...[
          const SizedBox(width: 4),
          MessageStatusIcon(status: m.status, size: 14, onBubble: true)
        ],
      ],
    );

    Widget content;
    if (m.type == MessageType.voice) {
      content = VoiceBubble(message: m, mine: mine);
    } else if (isMedia) {
      final url = m.mediaUrl ?? m.localPath;
      content = ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: 230,
          height: 260,
          child: Stack(
            fit: StackFit.expand,
            children: [
              m.type == MessageType.video
                  ? VideoSlide(url: url ?? '')
                  : GestureDetector(
                      onTap: () => _openImage(context, url),
                      child: AppImage(url),
                    ),
              if (m.status == MessageStatus.sending)
                Container(
                  color: Colors.black26,
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.6)),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                      color: Colors.black45, borderRadius: AppRadius.mdAll),
                  child: timeRow,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      content = Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.74),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : p.surface,
          borderRadius: radius,
          border: mine ? null : Border.all(color: p.border),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(m.content,
                style: context.text.bodyLarge?.copyWith(
                    color: mine ? Colors.white : p.text,
                    height: 1.35,
                    fontSize: 15.5)),
            Padding(padding: const EdgeInsets.only(bottom: 1), child: timeRow),
          ],
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (_, v, c) => Transform.scale(
        scale: 0.85 + 0.15 * v,
        alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
        child: Opacity(opacity: v.clamp(0, 1), child: c),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 2, bottom: tail ? 8 : 2),
        child: Row(
          mainAxisAlignment:
              mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (m.status == MessageStatus.failed)
              IconButton(
                onPressed: onRetry,
                icon:
                    const Icon(Icons.refresh_rounded, color: AppColors.danger),
                tooltip: context.tr('retry'),
              ),
            content,
          ],
        ),
      ),
    );
  }

  void _openImage(BuildContext context, String? url) {
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: false,
      pageBuilder: (ctx, a, __) => FadeTransition(
        opacity: a,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            color: Colors.black,
            child: InteractiveViewer(
                maxScale: 4,
                child: Center(child: AppImage(url, fit: BoxFit.contain))),
          ),
        ),
      ),
    ));
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: p.border),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Builder(builder: (_) {
                  final t = ((_c.value - i * 0.18) % 1.0);
                  final y = t < 0.5
                      ? -5 * (1 - (t * 4 - 1).abs()).clamp(0.0, 1.0)
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(0, y),
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: Color.lerp(p.textTertiary, AppColors.primary,
                            (-y / 5).clamp(0.0, 1.0)),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    super.key,
    required this.onMic,
    required this.controller,
    required this.focusNode,
    required this.emojiOpen,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
    required this.onEmoji,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool emojiOpen;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onEmoji;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final canSend = controller.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(
          10, 8, 10, emojiOpen ? 8 : MediaQuery.paddingOf(context).bottom + 8),
      decoration: BoxDecoration(
          color: p.bg, border: Border(top: BorderSide(color: p.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RoundIcon(
              icon: Icons.add_rounded,
              onTap: onAttach,
              color: p.surface2,
              iconColor: p.text),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: p.surface2, borderRadius: AppRadius.mdAll),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      style: context.text.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: context.tr('message'),
                        filled: false,
                        contentPadding:
                            const EdgeInsets.fromLTRB(18, 13, 4, 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onEmoji,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        emojiOpen
                            ? Icons.keyboard_rounded
                            : Icons.emoji_emotions_outlined,
                        key: ValueKey(emojiOpen),
                        color: p.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Пустое поле — микрофон, есть текст — отправка.
          Pressable(
            onTap: canSend ? onSend : onMic,
            scale: 0.85,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: canSend ? AppColors.lime : AppColors.primary,
                  shape: BoxShape.circle),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => RotationTransition(
                    turns: Tween(begin: 0.75, end: 1.0).animate(a),
                    child: ScaleTransition(scale: a, child: c)),
                child: Icon(
                  canSend ? Icons.arrow_upward_rounded : Icons.mic_rounded,
                  key: ValueKey(canSend),
                  color: canSend ? AppColors.ink : AppColors.cream,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(
      {required this.icon,
      required this.onTap,
      required this.color,
      required this.iconColor});
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.88,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor),
        ),
      );
}
