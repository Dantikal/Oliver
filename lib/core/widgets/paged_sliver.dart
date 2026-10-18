import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../pagination/paged.dart';
import '../theme/app_palette.dart';
import 'feedback.dart';

/// Обрабатывает все состояния пагинированного списка: skeleton / error / empty / data / load more.
class PagedSliver<T> extends StatelessWidget {
  const PagedSliver({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onRetryMore,
    required this.itemsBuilder,
    required this.skeleton,
    required this.empty,
    this.showEnd = true,
  });

  final PagedState<T> state;
  final VoidCallback onRetry;
  final VoidCallback onRetryMore;
  final Widget Function(BuildContext context, List<T> items) itemsBuilder;
  final Widget skeleton;
  final Widget empty;
  final bool showEnd;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) return skeleton;
    if (state.error != null && state.items.isEmpty) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child:
              Center(child: ErrorView(error: state.error, onRetry: onRetry)));
    }
    if (state.isEmpty) {
      return SliverFillRemaining(
          hasScrollBody: false, child: Center(child: empty));
    }
    return SliverMainAxisGroup(slivers: [
      itemsBuilder(context, state.items),
      SliverToBoxAdapter(
          child: _Footer(
              state: state, onRetryMore: onRetryMore, showEnd: showEnd)),
    ]);
  }
}

class _Footer extends StatelessWidget {
  const _Footer(
      {required this.state, required this.onRetryMore, required this.showEnd});
  final PagedState state;
  final VoidCallback onRetryMore;
  final bool showEnd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget child;
    if (state.isLoadingMore) {
      child = const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6));
    } else if (state.loadMoreError != null) {
      child = TextButton.icon(
        onPressed: onRetryMore,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(context.tr('retry')),
      );
    } else if (!state.hasMore && showEnd && state.items.length > 4) {
      child = Text(context.tr('endOfList'),
          style: context.text.bodySmall?.copyWith(color: p.textTertiary));
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(child: child));
  }
}

/// Возвращает true, если пора подгружать следующую страницу.
bool shouldLoadMore(ScrollNotification n) =>
    n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 700;
