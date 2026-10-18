import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/paged_sliver.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../../catalog/presentation/widgets/editorial.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../../chats/presentation/chat_controllers.dart';
import '../../favorites/presentation/favorites_controller.dart';
import '../../shell/main_shell.dart';
import '../data/profile_repositories.dart';
import '../../seller/presentation/listing_tools.dart';
import '../../seller/presentation/seller_dashboard_screen.dart';
import '../../store/presentation/store_manage_screen.dart';
import 'profile_cover.dart';
import 'profile_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _avatarLoading = false;

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: Text(ctx.tr('photoFromGallery'),
                    style: ctx.text.titleSmall),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppColors.leaf),
                title: Text(ctx.tr('takePhoto'), style: ctx.text.titleSmall),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      final f = await ImagePicker()
          .pickImage(source: source, maxWidth: 800, imageQuality: 85);
      if (f == null) return;
      setState(() => _avatarLoading = true);
      final repo = ref.read(profileRepositoryProvider);
      final url = await repo.uploadAvatar(f.path);
      final user = await repo.updateMe(avatarUrl: url);
      ref.read(authControllerProvider.notifier).updateUser(user);
      if (mounted) {
        context.showSnack(context.tr('avatarUpdated'), type: SnackType.success);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        context.showSnack(e.message ?? context.tr('errGeneric'),
            type: SnackType.error);
      }
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  Future<void> _editName() async {
    final user = ref.read(currentUserProvider);
    final c = TextEditingController(text: user?.fullName);
    final form = GlobalKey<FormState>();
    var saving = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              22, 0, 22, MediaQuery.viewInsetsOf(ctx).bottom + 22),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('editName'), style: ctx.text.headlineSmall),
                const SizedBox(height: 18),
                AppTextField(
                  controller: c,
                  label: ctx.tr('fullName'),
                  autofocus: true,
                  prefixIcon: Icons.person_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.fullName(ctx),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: ctx.tr('save'),
                  loading: saving,
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    setSheet(() => saving = true);
                    try {
                      final u = await ref
                          .read(profileRepositoryProvider)
                          .updateMe(fullName: c.text.trim());
                      ref.read(authControllerProvider.notifier).updateUser(u);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        context.showSnack(context.tr('saved'),
                            type: SnackType.success);
                      }
                    } catch (e) {
                      setSheet(() => saving = false);
                      if (mounted) context.showError(e);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    c.dispose();
  }

  Future<void> _delete(Product product) async {
    final ok = await showConfirmDialog(
      context,
      title: context.tr('deleteAdQ'),
      message: product.title,
      confirm: context.tr('delete'),
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    final ctrl = ref.read(myProductsPagedProvider.notifier);
    final before = ref.read(myProductsPagedProvider).items;
    ctrl.mutate((items) => items.where((p) => p.id != product.id).toList(),
        totalDelta: -1);
    try {
      await ref.read(productRepositoryProvider).delete(product.id);
      ref.read(productsPagedProvider.notifier).refresh();
      if (mounted) {
        context.showSnack(context.tr('adDeleted'), type: SnackType.success);
      }
    } catch (e) {
      ctrl.mutate((_) => before, totalDelta: 1);
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(myProductsPagedProvider);
    final ctrl = ref.read(myProductsPagedProvider.notifier);
    final favCount = ref.watch(favoritesCountProvider);
    final chatsCount = ref.watch(chatListProvider).valueOrNull?.length ?? 0;
    final grid = ref.watch(viewModeGridProvider);
    final cover = ref.watch(profileCoverProvider);

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
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
              SliverToBoxAdapter(
                child: ProfileHeader(
                  name: user?.fullName ?? '',
                  avatarUrl: user?.avatarUrl,
                  cover: cover,
                  avatarLoading: _avatarLoading,
                  onAvatarTap: _changeAvatar,
                  avatarBadge: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: AppColors.limeGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.bg, width: 2.5),
                      boxShadow: AppShadows.glow(AppColors.lime, strength: 0.6),
                    ),
                    child: const Icon(Icons.photo_camera_rounded,
                        color: AppColors.ink, size: 16),
                  ),
                  topActions: [
                    CoverButton(
                      icon: Icons.wallpaper_rounded,
                      label: context.tr('changeCover'),
                      onTap: () => showCoverPicker(context, ref),
                    ),
                    const Spacer(),
                    CoverButton(
                        icon: Icons.settings_rounded,
                        onTap: () => context.push('/settings')),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: staggered([
                      GestureDetector(
                        onTap: _editName,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(user?.fullName ?? '',
                                  style: context.text.displaySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.05)),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Icon(Icons.edit_outlined,
                                  size: 18, color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          for (final (icon, text) in [
                            if (user?.phone != null)
                              (Icons.call_outlined, user!.phone!),
                            if (user?.email != null)
                              (Icons.alternate_email_rounded, user!.email!),
                            if (user?.createdAt != null)
                              (
                                Icons.eco_outlined,
                                '${context.tr('onOliverSince')} ${user!.createdAt!.year}'
                              ),
                          ])
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 15, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Text(text,
                                    style: context.text.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      ProfileStats(items: [
                        (
                          value: '${state.total}',
                          label: context.tr('myAds'),
                          onTap: null
                        ),
                        (
                          value: '$favCount',
                          label: context.tr('favorites'),
                          onTap: () => context.go('/favorites')
                        ),
                        (
                          value: '$chatsCount',
                          label: context.tr('chats'),
                          onTap: () => context.go('/chats')
                        ),
                      ]),
                      const SizedBox(height: 18),
                      const MyStoreCard(),
                      const SizedBox(height: 8),
                      const SellerCabinetCard(),
                      const SizedBox(height: 8),
                      const ListingDraftCard(),
                      AppButton(
                        label: context.tr('postAd'),
                        icon: Icons.add_rounded,
                        variant: AppButtonVariant.lime,
                        onPressed: () => context.push('/create'),
                      ),
                      const SizedBox(height: 30),
                      SectionTitle(
                        number: '01',
                        title: context.tr('myAds'),
                        trailing: Text('${state.total}'.padLeft(2, '0'),
                            style: context.text.labelSmall?.copyWith(
                                color: p.textSecondary, letterSpacing: 1.2)),
                      ),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
              ),
              PagedSliver<Product>(
                state: state,
                onRetry: ctrl.refresh,
                onRetryMore: ctrl.retryLoadMore,
                skeleton: const ProductGridSkeleton(count: 4),
                showEnd: false,
                empty: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: context.tr('noMyAds'),
                  subtitle: context.tr('noMyAdsSub'),
                  action: context.tr('publish'),
                  onAction: () => context.push('/create'),
                ),
                itemsBuilder: (_, items) => ProductsSliver(
                  items: items,
                  grid: grid,
                  hero: false,
                  menuBuilder: (prod) => _AdMenu(
                    onEdit: () => context.push('/edit/${prod.id}', extra: prod),
                    onSimilar: () => context.push('/create', extra: prod),
                    onDelete: () => _delete(prod),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: kNavBarSpace)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdMenu extends StatelessWidget {
  const _AdMenu(
      {required this.onEdit, required this.onSimilar, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onSimilar;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      padding: EdgeInsets.zero,
      onSelected: (v) => switch (v) {
        0 => onEdit(),
        2 => onSimilar(),
        _ => onDelete(),
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 0,
          child: Row(children: [
            const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(ctx.tr('edit')),
          ]),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(children: [
            const Icon(Icons.copy_all_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(ctx.tr('makeSimilar')),
          ]),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(children: [
            const Icon(Icons.delete_rounded, size: 20, color: AppColors.danger),
            const SizedBox(width: 12),
            Text(ctx.tr('delete'),
                style: const TextStyle(color: AppColors.danger)),
          ]),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.55),
        ),
        child:
            const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}
