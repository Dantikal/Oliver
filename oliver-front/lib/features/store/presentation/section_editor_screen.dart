import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../data/store_repositories.dart';
import '../domain/store.dart';
import 'store_widgets.dart';

/// Товары одного отдела: порядок, хиты, перенос, добавление.
class SectionEditorScreen extends ConsumerWidget {
  const SectionEditorScreen({super.key, required this.sectionId});
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final store = ref.watch(myStoreProvider).valueOrNull;
    final section = store?.sections.where((s) => s.id == sectionId).firstOrNull;
    if (store == null || section == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final products =
        ref.watch(storeProductsProvider(store.ownerId)).valueOrNull ?? const [];
    final byId = {for (final pr in products) pr.id: pr};
    final items = [
      for (final id in section.productIds)
        if (byId[id] != null) byId[id]!
    ];
    final ctrl = ref.read(myStoreProvider.notifier);

    Future<void> guard(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        if (context.mounted) context.showError(e);
      }
    }

    Future<void> arrange(int Function(Product, Product) cmp) {
      HapticFeedback.selectionClick();
      final sorted = [...items]..sort(cmp);
      return guard(() =>
          ctrl.setSectionProducts(section.id, [for (final x in sorted) x.id]));
    }

    Future<void> edit() async {
      final r = await showSectionSheet(context,
          name: section.name, icon: section.icon);
      if (r != null) {
        await guard(
            () => ctrl.updateSection(section.id, name: r.name, icon: r.icon));
      }
    }

    Future<void> delete() async {
      final ok = await showConfirmDialog(context,
          title: context.tr('deleteSectionQ'),
          message: context.tr('deleteSectionSub'),
          confirm: context.tr('delete'),
          destructive: true,
          icon: Icons.delete_outline_rounded);
      if (ok && context.mounted) {
        context.pop();
        await guard(() => ctrl.deleteSection(section.id));
      }
    }

    Future<void> add() async {
      final picked = await _pickProducts(context, store, section, products);
      if (picked != null && picked.isNotEmpty) {
        HapticFeedback.lightImpact();
        await guard(() => ctrl.setSectionProducts(
            section.id, [...section.productIds, ...picked]));
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop()),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: edit,
          child: Row(
            children: [
              Icon(storeIcon(section.icon), color: AppColors.primary),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(section.name,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.headlineSmall)),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: edit),
          IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
              onPressed: delete),
        ],
      ),
      body: Column(
        children: [
          if (items.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                children: [
                  Center(
                    child: Text('${context.tr('sortBy')}:',
                        style: context.text.labelMedium
                            ?.copyWith(color: p.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  for (final (label, icon, cmp)
                      in <(String, IconData, int Function(Product, Product))>[
                    (
                      context.tr('sortCheap'),
                      Icons.south_rounded,
                      (a, b) => (a.price ?? double.infinity)
                          .compareTo(b.price ?? double.infinity)
                    ),
                    (
                      context.tr('sortExpensive'),
                      Icons.north_rounded,
                      (a, b) => (b.price ?? -1).compareTo(a.price ?? -1)
                    ),
                    (
                      context.tr('sortNewest'),
                      Icons.schedule_rounded,
                      (a, b) => b.createdAt.compareTo(a.createdAt)
                    ),
                    (
                      context.tr('sortName'),
                      Icons.sort_by_alpha_rounded,
                      (a, b) => a.title.compareTo(b.title)
                    ),
                  ]) ...[
                    FlatChip(
                        label: label,
                        icon: icon,
                        selected: false,
                        onTap: () => arrange(cmp)),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: storeIcon(section.icon),
                      title: context.tr('emptySection'),
                      subtitle: context.tr('emptySectionSub'),
                      action: context.tr('addProducts'),
                      onAction: add,
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    buildDefaultDragHandles: false,
                    itemCount: items.length,
                    onReorder: (a, b) {
                      HapticFeedback.selectionClick();
                      final ids = [for (final x in items) x.id];
                      final id = ids.removeAt(a);
                      ids.insert(b > a ? b - 1 : b, id);
                      guard(() => ctrl.setSectionProducts(section.id, ids));
                    },
                    itemBuilder: (_, i) {
                      final pr = items[i];
                      final hit = store.featuredIds.contains(pr.id);
                      return _ItemTile(
                        key: ValueKey(pr.id),
                        index: i,
                        product: pr,
                        hit: hit,
                        onHit: () => guard(() => ctrl.toggleFeatured(pr.id)),
                        onMenu: () =>
                            _itemMenu(context, ref, store, section, pr),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: AppButton(
            label: context.tr('addProducts'),
            icon: Icons.add_rounded,
            onPressed: add),
      ),
    );
  }

  Future<void> _itemMenu(BuildContext context, WidgetRef ref, Store store,
      StoreSection section, Product pr) async {
    final ctrl = ref.read(myStoreProvider.notifier);
    final hit = store.featuredIds.contains(pr.id);
    final others = store.sections.where((s) => s.id != section.id).toList();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(pr.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ctx.text.titleMedium),
              ),
              ListTile(
                leading: Icon(
                    hit ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppColors.warning),
                title: Text(ctx.tr(hit ? 'removeHit' : 'makeHit')),
                onTap: () => Navigator.pop(ctx, 'hit'),
              ),
              if (others.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(ctx.tr('moveTo').toUpperCase(),
                      style: ctx.text.labelSmall?.copyWith(letterSpacing: 1.2)),
                ),
                for (final s in others)
                  ListTile(
                    leading: Icon(storeIcon(s.icon), color: AppColors.primary),
                    title: Text(s.name),
                    onTap: () => Navigator.pop(ctx, 'move:${s.id}'),
                  ),
              ],
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded,
                    color: AppColors.danger),
                title: Text(ctx.tr('removeFromSection'),
                    style: const TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'hit') {
        await ctrl.toggleFeatured(pr.id);
      } else if (action == 'remove') {
        await ctrl.setSectionProducts(
            section.id, section.productIds.where((id) => id != pr.id).toList());
      } else if (action.startsWith('move:')) {
        await ctrl.moveProduct(pr.id, action.substring(5));
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.index,
    required this.product,
    required this.hit,
    required this.onHit,
    required this.onMenu,
  });

  final int index;
  final Product product;
  final bool hit;
  final VoidCallback onHit;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: p.border)),
      child: Row(
        children: [
          Text('${index + 1}'.padLeft(2, '0'),
              style: context.text.labelSmall?.copyWith(color: p.textTertiary)),
          const SizedBox(width: 8),
          SizedBox(width: 56, height: 56, child: AppImage(product.coverUrl)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall),
                const SizedBox(height: 2),
                PriceText(product: product, size: 14.5),
              ],
            ),
          ),
          IconButton(
            onPressed: onHit,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                hit ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey(hit),
                color: hit ? AppColors.warning : p.textTertiary,
              ),
            ),
          ),
          IconButton(
              onPressed: onMenu,
              icon: Icon(Icons.more_horiz_rounded, color: p.text)),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(Icons.drag_handle_rounded, color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Мультивыбор товаров для отдела. Возвращает id в порядке выбора.
Future<List<String>?> _pickProducts(BuildContext context, Store store,
    StoreSection section, List<Product> all) {
  final candidates =
      all.where((p) => !section.productIds.contains(p.id)).toList();
  final picked = <String>[];
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final p = ctx.palette;
      return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(ctx.tr('addProducts'), style: ctx.text.headlineSmall),
            ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(ctx.tr('allPlaced'), style: ctx.text.bodyMedium),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: candidates.length,
                  itemBuilder: (_, i) {
                    final pr = candidates[i];
                    final on = picked.contains(pr.id);
                    final from = store.sectionOf(pr.id);
                    return Pressable(
                      scale: 0.98,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        set(() =>
                            on ? picked.remove(pr.id) : picked.add(pr.id));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.lime
                                  .withValues(alpha: ctx.isDark ? 0.15 : 0.3)
                              : p.surface,
                          border: Border.all(
                              color: on ? AppColors.lime : p.border,
                              width: on ? 2 : 1),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 48,
                                height: 48,
                                child: AppImage(pr.coverUrl)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pr.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ctx.text.titleSmall),
                                  Text(from?.name ?? ctx.tr('noSection'),
                                      style: ctx.text.bodySmall),
                                ],
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  color: on ? AppColors.lime : p.surface2,
                                  shape: BoxShape.circle),
                              child: on
                                  ? const Icon(Icons.check_rounded,
                                      size: 18, color: AppColors.ink)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppButton(
                label: picked.isEmpty
                    ? ctx.tr('addN')
                    : '${ctx.tr('addN')} · ${picked.length}',
                onPressed:
                    picked.isEmpty ? null : () => Navigator.pop(ctx, picked),
              ),
            ),
          ],
        ),
      );
    }),
  );
}
