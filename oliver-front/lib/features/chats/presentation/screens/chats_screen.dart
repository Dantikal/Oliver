import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/paged_sliver.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/segmented.dart';
import '../../../../core/widgets/skeletons.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../notifications/data/notification_repositories.dart';
import '../../../notifications/domain/notification.dart';
import '../../../notifications/presentation/counters_controller.dart';
import '../../../shell/main_shell.dart';
import '../../domain/chat.dart';
import '../chat_controllers.dart';
import '../widgets/message_status_icon.dart';
import '../../../../core/widgets/motion.dart';

enum _Tab { messages, activity }

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key, this.initialTab});
  final String? initialTab;

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  late _Tab _tab =
      widget.initialTab == 'activity' ? _Tab.activity : _Tab.messages;

  @override
  void didUpdateWidget(ChatsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab &&
        widget.initialTab == 'activity') {
      setState(() => _tab = _Tab.activity);
    }
  }

  void _setTab(_Tab t) {
    setState(() => _tab = t);
    if (t == _Tab.activity) _markActivityRead();
  }

  Future<void> _markActivityRead() async {
    final items = ref.read(notificationsPagedProvider).items;
    final ids = items.where((n) => !n.isRead).map((n) => n.id).toList();
    try {
      await ref.read(notificationRepositoryProvider).markRead(ids);
      ref.read(countersProvider.notifier).clearActivity();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final counters = ref.watch(countersProvider);
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('chats'), style: context.text.displaySmall),
                  const SizedBox(height: 16),
                  AppSegmented<_Tab>(
                    items: _Tab.values,
                    value: _tab,
                    onChanged: _setTab,
                    labelOf: (t) => context
                        .tr(t == _Tab.messages ? 'messages' : 'activity'),
                    badgeOf: (t) => t == _Tab.messages
                        ? counters.unreadMessages
                        : counters.newLikes + counters.unreadNotifications,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0.04, 0), end: Offset.zero)
                            .animate(a),
                    child: c),
              ),
              child: _tab == _Tab.messages
                  ? const _MessagesTab(key: ValueKey('m'))
                  : const _ActivityTab(key: ValueKey('a')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesTab extends ConsumerWidget {
  const _MessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chatListProvider);
    final me = ref.watch(currentUserProvider)?.id;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        try {
          await ref.read(chatListProvider.notifier).refresh();
          await ref.read(countersProvider.notifier).refresh();
        } catch (e) {
          if (context.mounted) context.showError(e);
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          async.when(
            skipLoadingOnRefresh: true,
            loading: () => const ListSkeleton(),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                  child: ErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(chatListProvider))),
            ),
            data: (chats) => chats.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: context.tr('noChats'),
                        subtitle: context.tr('noChatsSub'),
                        action: context.tr('browseAds'),
                        onAction: () => context.go('/home'),
                      ),
                    ),
                  )
                : SliverList.builder(
                    itemCount: chats.length,
                    itemBuilder: (_, i) => FadeSlideIn(
                        index: i, child: _ChatTile(chat: chats[i], myId: me)),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: kNavBarSpace)),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.myId});
  final ChatSummary chat;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final last = chat.lastMessage;
    final mine = last?.senderId == myId;
    final unread = chat.unreadCount > 0;
    final previewIcon = switch (last?.type) {
      MessageType.image => Icons.photo_camera_outlined,
      MessageType.video => Icons.videocam_outlined,
      MessageType.voice => Icons.mic_none_rounded,
      _ => null,
    };
    final preview = switch (last?.type) {
      MessageType.image => context.tr('photo'),
      MessageType.video => context.tr('video'),
      MessageType.voice =>
        '${context.tr('voiceMessage')} ${formatVoiceDuration(int.tryParse(last!.content) ?? 0)}',
      _ => last?.content ?? context.tr('startChat'),
    };
    return Pressable(
      scale: 0.98,
      onTap: () => context.push('/chat/${chat.chatId}', extra: chat.peer),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.primary.withValues(alpha: context.isDark ? 0.1 : 0.06)
              : Colors.transparent,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                    url: chat.peer.avatarUrl,
                    name: chat.peer.fullName,
                    size: 58,
                    online: chat.isOnline),
                if (chat.productImage != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: p.bg, width: 2),
                      ),
                      child: AppImage(chat.productImage,
                          width: 24, height: 24, radius: 7),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(chat.peer.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium),
                      ),
                      Text(
                        formatChatTime(context, chat.updatedAt),
                        style: context.text.bodySmall?.copyWith(
                          color: unread ? AppColors.primary : p.textTertiary,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (chat.productTitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(chat.productTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                              color: AppColors.primary, fontSize: 11.5)),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (mine && last != null) ...[
                        MessageStatusIcon(status: last.status, size: 16),
                        const SizedBox(width: 4)
                      ],
                      if (previewIcon != null) ...[
                        Icon(previewIcon, size: 16, color: p.textSecondary),
                        const SizedBox(width: 4)
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: unread ? p.text : p.textSecondary,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        CountBadge(count: chat.unreadCount)
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsPagedProvider);
    final ctrl = ref.read(notificationsPagedProvider.notifier);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (shouldLoadMore(n)) ctrl.loadMore();
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: ctrl.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            PagedSliver<AppNotification>(
              state: state,
              onRetry: ctrl.refresh,
              onRetryMore: ctrl.retryLoadMore,
              skeleton: const ListSkeleton(),
              showEnd: false,
              empty: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: context.tr('noActivity'),
                  subtitle: context.tr('noActivitySub')),
              itemsBuilder: (_, items) => SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) =>
                    FadeSlideIn(index: i, child: _ActivityTile(n: items[i])),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: kNavBarSpace)),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.n});
  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, gradient) = switch (n.type) {
      NotificationType.like => (Icons.favorite_rounded, AppColors.leafGradient),
      NotificationType.comment => (
          Icons.chat_bubble_rounded,
          AppColors.forestGradient
        ),
      NotificationType.message => (Icons.mail_rounded, AppColors.brandGradient),
      NotificationType.system => (
          Icons.auto_awesome_rounded,
          AppColors.brandGradient
        ),
    };
    return Pressable(
      scale: 0.98,
      onTap: n.productId == null
          ? null
          : () => context.push('/product/${n.productId}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.isRead
              ? Colors.transparent
              : AppColors.leaf.withValues(alpha: context.isDark ? 0.08 : 0.05),
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                n.type == NotificationType.system || n.actorName == null
                    ? Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            gradient: gradient, shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white),
                      )
                    : AppAvatar(
                        url: n.actorAvatar, name: n.actorName!, size: 52),
                if (n.type != NotificationType.system)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          gradient: gradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.bg, width: 2)),
                      child: Icon(icon, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      if (n.type != NotificationType.system &&
                          n.actorName != null)
                        TextSpan(
                            text: '${n.actorName} ',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: n.text),
                    ]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(timeAgo(context, n.createdAt),
                      style: context.text.bodySmall
                          ?.copyWith(color: p.textTertiary)),
                ],
              ),
            ),
            if (n.productImage != null) ...[
              const SizedBox(width: 10),
              AppImage(n.productImage, width: 48, height: 48, radius: 12),
            ],
          ],
        ),
      ),
    );
  }
}
