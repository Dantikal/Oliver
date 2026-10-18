import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/presentation/widgets/editorial.dart';
import '../../profile/presentation/profile_cover.dart';
import '../data/store_repositories.dart';
import '../domain/store.dart';
import 'store_widgets.dart';

/// Ссылка на витрину магазина.
String storeLink(String userId) => 'https://oliver.kg/s/$userId';

/// Управление своим магазином: информация, отделы, хиты.
class StoreManageScreen extends ConsumerWidget {
  const StoreManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(myStoreProvider);
    return Scaffold(
      body: store.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: ErrorView(
                error: e, onRetry: () => ref.invalidate(myStoreProvider))),
        data: (s) => s == null ? const _CreateStore() : _Manage(store: s),
      ),
    );
  }
}

/// Онбординг: магазина ещё нет.
class _CreateStore extends ConsumerStatefulWidget {
  const _CreateStore();

  @override
  ConsumerState<_CreateStore> createState() => _CreateStoreState();
}

class _CreateStoreState extends ConsumerState<_CreateStore> {
  late final _name = TextEditingController(
      text: ref.read(currentUserProvider)?.fullName ?? '');
  final _desc = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(myStoreProvider.notifier)
          .create(_name.text.trim(), _desc.text.trim());
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, top + 8, 20, 32),
      children: staggered([
        Align(
          alignment: Alignment.centerLeft,
          child: _Back(onTap: () => context.pop()),
        ),
        const SizedBox(height: 22),
        Container(
          height: 150,
          decoration: BoxDecoration(
              color: AppColors.forest, borderRadius: AppRadius.xlAll),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned.fill(
                  child:
                      CoverArt(cover: ProfileCover.preset(CoverPreset.olive))),
              Center(
                child: Breathing(
                  builder: (_, t, child) =>
                      Transform.scale(scale: 1 + 0.05 * t, child: child),
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                        color: AppColors.lime, shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_rounded,
                        size: 38, color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(context.tr('createStore'),
            style: context.text.displaySmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(context.tr('createStoreSub'),
            style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
        const SizedBox(height: 22),
        AppTextField(
          controller: _name,
          label: context.tr('storeName'),
          prefixIcon: Icons.storefront_outlined,
          maxLength: 40,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _desc,
          label: context.tr('storeDesc'),
          prefixIcon: Icons.notes_rounded,
          maxLines: 3,
          maxLength: 160,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: context.tr('createStore'),
          icon: Icons.arrow_forward_rounded,
          loading: _saving,
          onPressed: _create,
        ),
      ]),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: p.border),
            boxShadow: AppShadows.soft(p.shadow, lift: 0.4)),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: p.text),
      ),
    );
  }
}

class _Manage extends ConsumerWidget {
  const _Manage({required this.store});
  final Store store;

  MyStoreController _ctrl(WidgetRef ref) => ref.read(myStoreProvider.notifier);

  Future<void> _guard(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  Future<void> _addSection(BuildContext context, WidgetRef ref) async {
    final r = await showSectionSheet(context);
    if (r != null && context.mounted) {
      await _guard(context, () => _ctrl(ref).addSection(r.name, r.icon));
    }
  }

  Future<void> _editInfo(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(text: store.name);
    final desc = TextEditingController(text: store.description);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.tr('storeInfo'), style: ctx.text.headlineSmall),
            const SizedBox(height: 16),
            AppTextField(
                controller: name,
                label: ctx.tr('storeName'),
                prefixIcon: Icons.storefront_outlined,
                maxLength: 40),
            const SizedBox(height: 12),
            AppTextField(
                controller: desc,
                label: ctx.tr('storeDesc'),
                prefixIcon: Icons.notes_rounded,
                maxLines: 3,
                maxLength: 160),
            const SizedBox(height: 16),
            AppButton(
                label: ctx.tr('save'),
                onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted && name.text.trim().isNotEmpty) {
      await _guard(
          context,
          () => _ctrl(ref).updateInfo(
              name: name.text.trim(), description: desc.text.trim()));
    }
    name.dispose();
    desc.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final me = ref.watch(currentUserProvider);
    final cover = ref.watch(profileCoverProvider);
    final products = ref.watch(storeProductsProvider(store.ownerId));
    final all = products.valueOrNull ?? const [];
    final placed = {for (final s in store.sections) ...s.productIds};
    final unsorted = all.where((p) => !placed.contains(p.id)).length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: StoreHeader(
            cover: cover,
            name: store.name,
            ownerName: me?.fullName ?? '',
            avatarUrl: me?.avatarUrl,
            description: store.description,
            chips: [
              if (store.pickup) context.tr('pickup'),
              if (store.delivery) context.tr('deliveryOpt'),
              '${context.tr('itemsCap')} · ${all.length}',
            ],
            topActions: [
              OverCoverButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => context.pop()),
              const Spacer(),
              OverCoverButton(
                icon: Icons.ios_share_rounded,
                onTap: () =>
                    Share.share('${store.name}\n${storeLink(store.ownerId)}'),
              ),
              const SizedBox(width: 8),
              OverCoverButton(
                icon: Icons.visibility_outlined,
                label: context.tr('openStorefront'),
                onTap: () => context.push('/store/${store.ownerId}'),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Информация и способы получения.
                Container(
                  decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(color: p.border)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_note_rounded,
                            color: AppColors.primary),
                        title: Text(context.tr('storeInfo'),
                            style: context.text.titleSmall),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: p.textTertiary),
                        onTap: () => _editInfo(context, ref),
                      ),
                      Divider(height: 1, color: p.border),
                      SwitchListTile(
                        secondary: const Icon(Icons.storefront_outlined,
                            color: AppColors.primary),
                        title: Text(context.tr('pickup'),
                            style: context.text.titleSmall),
                        value: store.pickup,
                        onChanged: (v) => _guard(
                            context, () => _ctrl(ref).updateInfo(pickup: v)),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.local_shipping_outlined,
                            color: AppColors.primary),
                        title: Text(context.tr('deliveryOpt'),
                            style: context.text.titleSmall),
                        value: store.delivery,
                        onChanged: (v) => _guard(
                            context, () => _ctrl(ref).updateInfo(delivery: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SectionTitle(
                  number: '01',
                  title: context.tr('sections'),
                  trailing: Text('${store.sections.length}'.padLeft(2, '0'),
                      style: context.text.labelSmall?.copyWith(
                          color: p.textSecondary, letterSpacing: 1.2)),
                ),
                const SizedBox(height: 6),
                Text(context.tr('dragHint'),
                    style: context.text.bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        // Отделы с перетаскиванием.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverReorderableList(
            itemCount: store.sections.length,
            onReorder: (a, b) {
              HapticFeedback.selectionClick();
              _guard(context, () => _ctrl(ref).reorderSections(a, b));
            },
            proxyDecorator: (child, _, a) => AnimatedBuilder(
              animation: a,
              builder: (_, c) => Transform.scale(
                  scale: 1 + 0.03 * a.value,
                  child: Material(
                      elevation: 8 * a.value,
                      color: Colors.transparent,
                      child: c)),
              child: child,
            ),
            itemBuilder: (_, i) {
              final s = store.sections[i];
              return _SectionTile(
                key: ValueKey(s.id),
                index: i,
                section: s,
                onOpen: () => context.push('/store/section/${s.id}'),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pressable(
                  onTap: () => _addSection(context, ref),
                  scale: 0.98,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                        border: Border.all(color: p.border),
                        borderRadius: AppRadius.lgAll),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: p.text),
                        const SizedBox(width: 8),
                        Text(context.tr('addSection'),
                            style: context.text.titleSmall),
                      ],
                    ),
                  ),
                ),
                if (unsorted > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.lime
                            .withValues(alpha: context.isDark ? 0.14 : 0.35),
                        borderRadius: AppRadius.mdAll),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, color: p.text),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              '${context.tr('itemsCap')} · $unsorted — ${context.tr('unsortedTip')}',
                              style: context.text.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (products.isLoading) ...[
                  const SizedBox(height: 14),
                  const ShimmerWrap(
                      child: Bone(width: double.infinity, height: 60)),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 40)),
      ],
    );
  }
}

class _SectionTile extends ConsumerWidget {
  const _SectionTile(
      {super.key,
      required this.index,
      required this.section,
      required this.onOpen});
  final int index;
  final StoreSection section;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: p.border)),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.mdAll),
                child: Icon(storeIcon(section.icon), color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            context.text.titleSmall?.copyWith(fontSize: 15.5)),
                    Text(
                        '${context.tr('itemsCap')} · ${section.productIds.length}',
                        style: context.text.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.textTertiary),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child:
                      Icon(Icons.drag_handle_rounded, color: p.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка «Мой магазин» в профиле.
class MyStoreCard extends ConsumerWidget {
  const MyStoreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final store = ref.watch(myStoreProvider).valueOrNull;
    final count = store == null
        ? 0
        : store.sections.fold<int>(0, (s, x) => s + x.productIds.length);
    return Pressable(
      onTap: () => context.push('/store/manage'),
      scale: 0.98,
      child: Glass(
        radius: AppRadius.lg,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppColors.limeGradient,
                borderRadius: AppRadius.mdAll,
                boxShadow: AppShadows.glow(AppColors.lime, strength: 0.5),
              ),
              child: const Icon(Icons.storefront_rounded, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      (store == null ? context.tr('myStore') : store.name)
                          .toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall
                          ?.copyWith(color: p.text, letterSpacing: 1.3)),
                  const SizedBox(height: 3),
                  Text(
                    store == null
                        ? context.tr('createStoreSub')
                        : '${context.tr('sections')} · ${store.sections.length}   ${context.tr('itemsCap')} · $count',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall
                        ?.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: p.text),
          ],
        ),
      ),
    );
  }
}
