import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/paged_sliver.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/skeletons.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/catalog_providers.dart';
import '../../domain/comment.dart';
import '../catalog_controllers.dart';
import '../../../../core/widgets/motion.dart';

class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Comment? _replyTo;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reply(Comment c) {
    setState(() => _replyTo = c);
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await ref
          .read(commentRepositoryProvider)
          .add(widget.productId, text, parentCommentId: _replyTo?.id);
      final ctrl = ref.read(commentsPagedProvider(widget.productId).notifier);
      final parent = _replyTo;
      if (parent == null) {
        ctrl.mutate((items) => [c, ...items], totalDelta: 1);
      } else {
        ctrl.mutate((items) => items
            .map((i) => i.mapTree(
                parent.id, (p) => p.copyWith(replies: [...p.replies, c])))
            .toList());
      }
      _text.clear();
      setState(() => _replyTo = null);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(Comment c) async {
    final ctrl = ref.read(commentsPagedProvider(widget.productId).notifier);
    void apply(bool liked, int count) => ctrl.mutate((items) => items
        .map((i) => i.mapTree(
            c.id, (x) => x.copyWith(isLiked: liked, likesCount: count)))
        .toList());
    final liked = !c.isLiked;
    HapticFeedback.selectionClick();
    apply(liked, c.likesCount + (liked ? 1 : -1));
    try {
      final repo = ref.read(commentRepositoryProvider);
      final count = liked ? await repo.like(c.id) : await repo.unlike(c.id);
      apply(liked, count);
    } catch (e) {
      apply(c.isLiked, c.likesCount);
      if (mounted) context.showError(e);
    }
  }

  Future<void> _delete(Comment c) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('deleteCommentQ'),
      message: context.tr('deleteCommentSub'),
      confirm: context.tr('delete'),
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    try {
      await ref.read(commentRepositoryProvider).delete(c.id);
      ref.read(commentsPagedProvider(widget.productId).notifier).mutate(
          (items) => items
              .map((i) => i.removeFromTree(c.id))
              .whereType<Comment>()
              .toList(),
          totalDelta: c.parentCommentId == null ? -1 : 0);
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = ref.watch(commentsPagedProvider(widget.productId));
    final ctrl = ref.read(commentsPagedProvider(widget.productId).notifier);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop()),
        title: Row(
          children: [
            Text(context.tr('comments')),
            const SizedBox(width: 10),
            if (!state.isLoading) CountBadge(count: state.total),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
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
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    PagedSliver<Comment>(
                      state: state,
                      onRetry: ctrl.refresh,
                      onRetryMore: ctrl.retryLoadMore,
                      skeleton: const ListSkeleton(avatar: 40),
                      showEnd: false,
                      empty: EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: context.tr('noComments'),
                        subtitle: context.tr('noCommentsSub'),
                      ),
                      itemsBuilder: (_, items) => SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) => FadeSlideIn(
                          index: i,
                          child: _CommentTree(
                            comment: items[i],
                            depth: 0,
                            myId: me?.id,
                            onReply: _reply,
                            onLike: _toggleLike,
                            onDelete: _delete,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _InputBar(
            controller: _text,
            focusNode: _focus,
            replyTo: _replyTo,
            sending: _sending,
            onCancelReply: () => setState(() => _replyTo = null),
            onSend: _send,
            avatarUrl: me?.avatarUrl,
            name: me?.fullName ?? '',
          ),
        ],
      ),
      backgroundColor: p.bg,
    );
  }
}

class _CommentTree extends StatefulWidget {
  const _CommentTree({
    required this.comment,
    required this.depth,
    required this.myId,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  final Comment comment;
  final int depth;
  final String? myId;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onLike;
  final ValueChanged<Comment> onDelete;

  @override
  State<_CommentTree> createState() => _CommentTreeState();
}

class _CommentTreeState extends State<_CommentTree> {
  late bool _expanded = widget.depth > 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = widget.comment;
    final indent = widget.depth == 0 ? 0.0 : 44.0;
    return Padding(
      padding: EdgeInsets.only(left: widget.depth == 1 ? indent : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: c.userId == widget.myId
                      ? null
                      : () => context.push('/user/${c.userId}'),
                  child: AppAvatar(
                      url: c.avatarUrl,
                      name: c.fullName,
                      size: widget.depth == 0 ? 40 : 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onLongPress: c.userId == widget.myId
                        ? () => widget.onDelete(c)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(c.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleSmall),
                            ),
                            const SizedBox(width: 8),
                            Text(timeAgo(context, c.createdAt),
                                style: context.text.bodySmall?.copyWith(
                                    color: p.textTertiary, fontSize: 11.5)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(c.text,
                            style: context.text.bodyMedium
                                ?.copyWith(height: 1.45)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => widget.onReply(c),
                              child: Text(context.tr('reply'),
                                  style: context.text.labelMedium?.copyWith(
                                      color: p.textSecondary,
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (c.userId == widget.myId) ...[
                              const SizedBox(width: 18),
                              GestureDetector(
                                onTap: () => widget.onDelete(c),
                                child: Text(context.tr('delete'),
                                    style: context.text.labelMedium?.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _LikeButton(
                    liked: c.isLiked,
                    count: c.likesCount,
                    onTap: () => widget.onLike(c)),
              ],
            ),
          ),
          if (c.replies.isNotEmpty && !_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 68, top: 4, bottom: 4),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 24, height: 1.5, color: p.surface3),
                    const SizedBox(width: 8),
                    Text(
                      context
                          .tr('showReplies')
                          .replaceAll('{n}', '${c.totalReplies}'),
                      style: context.text.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          if (_expanded)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: Column(
                children: [
                  for (final r in c.replies)
                    _CommentTree(
                      comment: r,
                      depth: widget.depth + 1,
                      myId: widget.myId,
                      onReply: widget.onReply,
                      onLike: widget.onLike,
                      onDelete: widget.onDelete,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton(
      {required this.liked, required this.count, required this.onTap});
  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.8,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 2),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(liked),
                size: 20,
                color: liked ? AppColors.leaf : p.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text('$count',
                style: context.text.labelSmall
                    ?.copyWith(color: liked ? AppColors.leaf : p.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.sending,
    required this.onCancelReply,
    required this.onSend,
    required this.avatarUrl,
    required this.name,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Comment? replyTo;
  final bool sending;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.paddingOf(context).bottom + 10),
      decoration: BoxDecoration(
          color: p.surface, border: Border(top: BorderSide(color: p.border))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: replyTo == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.reply_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '${context.tr('replyTo')} ${replyTo!.fullName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                        GestureDetector(
                          onTap: onCancelReply,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded,
                                size: 18, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Row(
            children: [
              AppAvatar(url: avatarUrl, name: name, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: context.text.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: context.tr('writeComment'),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: const OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: BorderSide.none),
                    enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: BorderSide.none),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Pressable(
                onTap: onSend,
                scale: 0.88,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
