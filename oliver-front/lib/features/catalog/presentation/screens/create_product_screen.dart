import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/phone_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/picker_sheet.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/segmented.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../seller/data/listing_draft.dart';
import '../../../seller/presentation/listing_quality.dart';
import '../../../seller/presentation/listing_tools.dart';
import '../../../seller/presentation/options_editor.dart';
import '../../data/catalog_providers.dart';
import '../../domain/product.dart';
import '../../domain/reference.dart';
import '../catalog_controllers.dart';
import '../widgets/product_card.dart';

/// Медиа в черновике: либо уже загруженное (url), либо локальный файл.
class _DraftMedia {
  _DraftMedia({this.uploaded, this.path, required this.type})
      : key = UniqueKey();
  final Key key;
  final MediaItem? uploaded;
  final String? path;
  final MediaType type;

  String get preview => uploaded?.thumbnailUrl ?? uploaded?.url ?? path!;
  bool get isVideo => type == MediaType.video;
}

/// Быстрые фразы для описания.
const _phrases = [
  'phNew',
  'phUsed',
  'phBox',
  'phWarranty',
  'phBargain',
  'phDelivery',
  'phNoSwap',
];

class CreateProductScreen extends ConsumerStatefulWidget {
  const CreateProductScreen({super.key, this.initial, this.template});

  /// Редактирование существующего объявления.
  final Product? initial;

  /// «Создать похожее»: новое объявление, заполненное из этого.
  final Product? template;

  @override
  ConsumerState<CreateProductScreen> createState() =>
      _CreateProductScreenState();
}

class _CreateProductScreenState extends ConsumerState<CreateProductScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  final _wa = TextEditingController();
  final _tg = TextEditingController();
  List<TextEditingController> get _controllers =>
      [_title, _price, _desc, _phone, _wa, _tg];

  final List<_DraftMedia> _media = [];
  List<ProductOption> _options = [];
  Currency _currency = Currency.kgs;
  String? _categoryId;
  String? _categoryName;
  Region? _region;
  City? _city;

  bool _submitted = false;
  bool _saving = false;
  String? _progress;

  /// Что-то изменили после открытия.
  bool _dirty = false;
  bool _published = false;
  bool _draftBanner = false;
  Timer? _saveTimer;
  late final _drafts = ref.read(listingDraftProvider.notifier);

  bool get _isEdit => widget.initial != null;
  int get _photos => _media.where((m) => !m.isVideo).length;
  int get _videos => _media.where((m) => m.isVideo).length;

  @override
  void initState() {
    super.initState();
    final src = widget.initial ?? widget.template;
    final draft = src == null ? ref.read(listingDraftProvider) : null;
    if (src != null) {
      _fillFromProduct(src);
    } else if (draft != null) {
      _fillFromDraft(draft);
      _draftBanner = true;
    } else {
      _fillDefaults();
    }
    for (final c in _controllers) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Закрыли свайпом/кнопкой — черновик не теряем. Отложенно: во время
    // dispose дерево заблокировано, а карточку черновика надо перестроить.
    if (!_isEdit && _dirty && !_published) {
      final draft = _toDraft();
      final drafts = _drafts;
      Future.microtask(() => drafts.save(draft));
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- state

  void _fillFromProduct(Product p) {
    _title.text = p.title;
    if (!p.currency.isPriceless && p.price != null) {
      _price.text = p.price!.toStringAsFixed(0);
    }
    _desc.text = p.description;
    _phone.text = KgPhoneFormatter.fromFull(
        p.phone ?? ref.read(currentUserProvider)?.phone);
    _wa.text = p.whatsappLink ?? '';
    _tg.text = p.telegramLink ?? '';
    _media.addAll(
        [for (final m in p.media) _DraftMedia(uploaded: m, type: m.type)]);
    _options = [...p.options];
    _currency = p.currency;
    _categoryId = p.categoryId;
    _categoryName = p.categoryName;
    _region = Region(id: p.regionId, name: p.regionName);
    _city = City(id: p.cityId, name: p.cityName);
  }

  void _fillFromDraft(ListingDraft d) {
    _title.text = d.title;
    _price.text = d.price;
    _desc.text = d.description;
    _phone.text = d.phone.isNotEmpty
        ? d.phone
        : KgPhoneFormatter.fromFull(ref.read(currentUserProvider)?.phone);
    _wa.text = d.whatsapp;
    _tg.text = d.telegram;
    _media.addAll([
      for (final m in d.media)
        _DraftMedia(uploaded: m.uploaded, path: m.path, type: m.type)
    ]);
    _options = [...d.options];
    _currency = d.currency;
    _categoryId = d.categoryId;
    _categoryName = d.categoryName;
    _region = d.regionId == null
        ? null
        : Region(id: d.regionId!, name: d.regionName ?? '');
    _city =
        d.cityId == null ? null : City(id: d.cityId!, name: d.cityName ?? '');
  }

  /// Новое объявление с нуля: место и мессенджеры — как в прошлый раз.
  void _fillDefaults() {
    final d = ref.read(sellerDefaultsProvider);
    _phone.text =
        KgPhoneFormatter.fromFull(ref.read(currentUserProvider)?.phone);
    _wa.text = d.whatsapp ?? '';
    _tg.text = d.telegram ?? '';
    _region = d.regionId == null
        ? null
        : Region(id: d.regionId!, name: d.regionName ?? '');
    _city =
        d.cityId == null ? null : City(id: d.cityId!, name: d.cityName ?? '');
  }

  void _changed() {
    if (!mounted) return;
    setState(() => _dirty = true);
    if (_isEdit) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
        const Duration(milliseconds: 600), () => _drafts.save(_toDraft()));
  }

  ListingDraft _toDraft() => ListingDraft(
        title: _title.text,
        price: _price.text,
        description: _desc.text,
        currency: _currency,
        categoryId: _categoryId,
        categoryName: _categoryName,
        regionId: _region?.id,
        regionName: _region?.name,
        cityId: _city?.id,
        cityName: _city?.name,
        phone: _phone.text,
        whatsapp: _wa.text,
        telegram: _tg.text,
        media: [
          for (final m in _media)
            DraftMediaData(type: m.type, uploaded: m.uploaded, path: m.path)
        ],
        options: _options,
        updatedAt: DateTime.now(),
      );

  void _startOver() {
    HapticFeedback.mediumImpact();
    _saveTimer?.cancel();
    for (final c in _controllers) {
      c.removeListener(_changed);
      c.clear();
    }
    _media.clear();
    _options = [];
    _currency = Currency.kgs;
    _categoryId = null;
    _categoryName = null;
    _fillDefaults();
    for (final c in _controllers) {
      c.addListener(_changed);
    }
    _drafts.clear();
    setState(() {
      _draftBanner = false;
      _dirty = false;
      _submitted = false;
    });
  }

  Future<void> _close() async {
    FocusScope.of(context).unfocus();
    if (_isEdit && _dirty) {
      final leave = await showConfirmDialog(context,
          title: context.tr('discardQ'),
          message: context.tr('discardSub'),
          confirm: context.tr('leave'),
          destructive: true,
          icon: Icons.edit_off_rounded);
      if (!leave || !mounted) return;
      setState(() => _dirty = false);
    } else if (!_isEdit && _dirty && _toDraft().hasContent) {
      _saveTimer?.cancel();
      _drafts.save(_toDraft());
      context.showSnack(context.tr('draftSaved'));
    }
    if (mounted) context.pop();
  }

  /// Текущая форма как объявление — для оценки качества и предпросмотра.
  Product _asProduct() => Product(
        id: 'preview',
        title: _title.text.trim(),
        description: _desc.text.trim(),
        price: double.tryParse(_price.text),
        currency: _currency,
        categoryId: _categoryId ?? '',
        categoryName: _categoryName ?? '',
        regionId: _region?.id ?? '',
        regionName: _region?.name ?? '',
        cityId: _city?.id ?? '',
        cityName: _city?.name ?? '',
        whatsappLink: _wa.text.trim().isEmpty ? null : _wa.text.trim(),
        telegramLink: _tg.text.trim().isEmpty ? null : _tg.text.trim(),
        options: _options,
        media: [
          for (final m in _media)
            MediaItem(
                id: '${m.key}',
                url: m.uploaded?.url ?? m.path!,
                type: m.type,
                thumbnailUrl: m.uploaded?.thumbnailUrl)
        ],
        seller:
            ref.read(currentUserProvider) ?? const User(id: '', fullName: ''),
        createdAt: DateTime.now(),
      );

  /// Сколько обязательных полей ещё пусто.
  int get _requiredLeft => [
        _photos > 0,
        _title.text.trim().isNotEmpty,
        _categoryId != null,
        _currency.isPriceless || (int.tryParse(_price.text) ?? 0) > 0,
        _region != null && _city != null,
        _desc.text.trim().length >= 10,
        KgPhoneFormatter.digitsOf(_phone.text).length == 9,
      ].where((ok) => !ok).length;

  // ---------------------------------------------------------------- media

  String? _validateFile(String path, MediaType type) {
    final ext = path.split('.').last.toLowerCase();
    final allowed = type == MediaType.video
        ? AppConfig.videoExtensions
        : AppConfig.photoExtensions;
    if (!allowed.contains(ext)) return '${context.tr('badFormat')}: .$ext';
    final mb = File(path).lengthSync() / (1024 * 1024);
    final max =
        type == MediaType.video ? AppConfig.maxVideoMb : AppConfig.maxPhotoMb;
    if (mb > max) return context.tr('fileTooBig').replaceAll('{n}', '$max');
    return null;
  }

  void _addFiles(List<String> paths, MediaType type) {
    final errors = <String>[];
    for (final path in paths) {
      final limit =
          type == MediaType.video ? AppConfig.maxVideos : AppConfig.maxPhotos;
      final count = type == MediaType.video ? _videos : _photos;
      if (count >= limit) {
        errors.add(context.tr('limitReached').replaceAll('{n}', '$limit'));
        break;
      }
      final err = _validateFile(path, type);
      if (err != null) {
        errors.add(err);
        continue;
      }
      _media.add(_DraftMedia(path: path, type: type));
    }
    _changed();
    if (errors.isNotEmpty) {
      context.showSnack(errors.first, type: SnackType.error);
    }
  }

  Future<void> _pickMedia() async {
    final p = context.palette;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, icon, label, color) in [
                (
                  0,
                  Icons.photo_library_rounded,
                  ctx.tr('photoFromGallery'),
                  AppColors.primary
                ),
                (
                  1,
                  Icons.photo_camera_rounded,
                  ctx.tr('takePhoto'),
                  AppColors.leaf
                ),
                (
                  2,
                  Icons.video_library_rounded,
                  ctx.tr('videoFromGallery'),
                  AppColors.mint
                ),
                (
                  3,
                  Icons.folder_open_rounded,
                  ctx.tr('fromFiles'),
                  AppColors.teal
                ),
              ])
                ListTile(
                  onTap: () => Navigator.pop(ctx, i),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.13),
                        borderRadius: AppRadius.mdAll),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(label,
                      style: ctx.text.titleSmall?.copyWith(fontSize: 15.5)),
                  trailing:
                      Icon(Icons.chevron_right_rounded, color: p.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    final picker = ImagePicker();
    try {
      switch (choice) {
        case 0:
          final files =
              await picker.pickMultiImage(imageQuality: 85, maxWidth: 2400);
          _addFiles(files.map((f) => f.path).toList(), MediaType.image);
        case 1:
          final f = await picker.pickImage(
              source: ImageSource.camera, imageQuality: 85, maxWidth: 2400);
          if (f != null) _addFiles([f.path], MediaType.image);
        case 2:
          final f = await picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(minutes: 2));
          if (f != null) _addFiles([f.path], MediaType.video);
        case 3:
          final files =
              await picker.pickMultipleMedia(imageQuality: 85, maxWidth: 2400);
          final paths = files.map((f) => f.path).toList();
          bool isVideo(String p) => AppConfig.videoExtensions
              .contains(p.split('.').last.toLowerCase());
          _addFiles(paths.where((p) => !isVideo(p)).toList(), MediaType.image);
          _addFiles(paths.where(isVideo).toList(), MediaType.video);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        context.showSnack(e.message ?? context.tr('errGeneric'),
            type: SnackType.error);
      }
    }
  }

  /// Тап по фото: сделать обложкой или удалить.
  Future<void> _mediaActions(int i) async {
    final m = _media[i];
    final isCover = i == _media.indexWhere((x) => !x.isVideo);
    final action = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!m.isVideo && !isCover)
                ListTile(
                  leading:
                      const Icon(Icons.star_rounded, color: AppColors.primary),
                  title: Text(ctx.tr('makeCover'), style: ctx.text.titleSmall),
                  onTap: () => Navigator.pop(ctx, 0),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                title: Text(ctx.tr('delete'),
                    style:
                        ctx.text.titleSmall?.copyWith(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, 1),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    HapticFeedback.selectionClick();
    if (action == 0) {
      _media.insert(0, _media.removeAt(i));
    } else {
      _media.removeAt(i);
    }
    _changed();
  }

  // ---------------------------------------------------------------- pickers

  /// Раздел «Отдам даром»: цена не нужна, ставится «Даром».
  bool get _giveaway => _currency == Currency.free;

  bool _isGiveawayCategory(String id) {
    for (final c in ref.read(categoriesProvider).valueOrNull ?? const []) {
      if (c.id == id || c.children.any((s) => s.id == id)) return c.isGiveaway;
    }
    return false;
  }

  void _setCategory(String id, String name) {
    _categoryId = id;
    _categoryName = name;
    if (_isGiveawayCategory(id)) {
      _currency = Currency.free;
    } else if (_currency == Currency.free) {
      _currency = Currency.kgs;
    }
    _changed();
  }

  Future<void> _pickCategory() async {
    final cats = await ref.read(categoriesProvider.future);
    if (!mounted) return;
    final root = await showPickerSheet<ProductCategory>(
      context,
      title: context.tr('category'),
      items: cats,
      labelOf: (c) => c.name,
      leading: (c) =>
          Icon(categoryIcon(c.icon), size: 22, color: AppColors.primary),
      subtitleOf: (c) => c.children.isEmpty
          ? null
          : c.children.map((e) => e.name).take(3).join(', '),
      isSelected: (c) =>
          c.id == _categoryId || c.children.any((s) => s.id == _categoryId),
    );
    if (root == null || !mounted) return;
    if (root.children.isEmpty) return _setCategory(root.id, root.name);
    final sub = await showPickerSheet<ProductCategory>(
      context,
      title: root.name,
      items: root.children,
      labelOf: (c) => c.name,
      isSelected: (c) => c.id == _categoryId,
    );
    if (sub != null) _setCategory(sub.id, '${root.name} · ${sub.name}');
  }

  Future<void> _pickRegion() async {
    final regions = await ref.read(regionsProvider.future);
    if (!mounted) return;
    final r = await showPickerSheet<Region>(
      context,
      title: context.tr('region'),
      items: regions,
      labelOf: (r) => r.name,
      isSelected: (r) => r.id == _region?.id,
    );
    if (r != null && r.id != _region?.id) {
      _region = r;
      _city = null;
      _changed();
    }
  }

  Future<void> _pickCity() async {
    if (_region == null) return;
    final cities = await ref.read(citiesProvider(_region!.id).future);
    if (!mounted) return;
    final c = await showPickerSheet<City>(
      context,
      title: context.tr('city'),
      items: cities,
      labelOf: (c) => c.name,
      isSelected: (c) => c.id == _city?.id,
    );
    if (c != null) {
      _city = c;
      _changed();
    }
  }

  void _appendPhrase(String phrase) {
    HapticFeedback.selectionClick();
    final t = _desc.text.trimRight();
    _desc.text = t.isEmpty ? phrase : '$t\n$phrase';
    _desc.selection = TextSelection.collapsed(offset: _desc.text.length);
  }

  // ---------------------------------------------------------------- preview

  void _showPreview() {
    FocusScope.of(context).unfocus();
    final pr = _asProduct();
    final product =
        pr.title.isEmpty ? pr.copyWith(title: context.tr('untitled')) : pr;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final p = ctx.palette;
        Widget label(String s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(s.toUpperCase(),
                  style: ctx.text.labelSmall
                      ?.copyWith(color: p.textSecondary, letterSpacing: 1.3)),
            );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('previewTitle'), style: ctx.text.headlineSmall),
                const SizedBox(height: 18),
                label(ctx.tr('previewInFeed')),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: ProductGridCard(
                            product: product,
                            hero: false,
                            trailingMenu: const SizedBox.shrink())),
                    const SizedBox(width: 12),
                    // Соседняя карточка-призрак — чтобы видеть масштаб в ленте.
                    Expanded(
                      child: Opacity(
                        opacity: 0.35,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                                aspectRatio: 0.8,
                                child: Container(color: p.surface2)),
                            const SizedBox(height: 10),
                            Container(
                                height: 12, width: 120, color: p.surface2),
                            const SizedBox(height: 8),
                            Container(height: 10, width: 70, color: p.surface2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                label(ctx.tr('previewInList')),
                ProductListCard(product: product, hero: false),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- submit

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    final valid = _form.currentState!.validate();
    if (!valid ||
        _photos == 0 ||
        _categoryId == null ||
        _region == null ||
        _city == null) {
      HapticFeedback.heavyImpact();
      context.showSnack(context.tr('fillRequired'), type: SnackType.error);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(productRepositoryProvider);
    try {
      final uploaded = <MediaItem>[];
      final toUpload = _media.where((m) => m.uploaded == null).length;
      var done = 0;
      for (final m in _media) {
        if (m.uploaded != null) {
          uploaded.add(m.uploaded!);
          continue;
        }
        setState(() =>
            _progress = '${context.tr('uploadingMedia')} ${++done}/$toUpload');
        uploaded.add(await repo.uploadMedia(m.path!, m.type));
      }
      setState(() => _progress = null);
      final wa = _wa.text.trim().isEmpty ? null : _wa.text.trim();
      final tg = _tg.text.trim().isEmpty ? null : _tg.text.trim();
      final draft = ProductDraft(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        categoryId: _categoryId!,
        price: _currency.isPriceless ? null : double.tryParse(_price.text),
        currency: _currency,
        regionId: _region!.id,
        cityId: _city!.id,
        phone: KgPhoneFormatter.toFull(_phone.text),
        whatsappLink: wa,
        telegramLink: tg,
        media: uploaded,
        // Пустые группы покупателю не нужны.
        options: [
          for (final o in _options)
            if (o.values.isNotEmpty) o
        ],
      );
      final product = _isEdit
          ? await repo.update(widget.initial!.id, draft)
          : await repo.create(draft);
      _published = true;
      _saveTimer?.cancel();
      if (!_isEdit) _drafts.clear();
      ref.read(sellerDefaultsProvider.notifier).remember(
            regionId: _region!.id,
            regionName: _region!.name,
            cityId: _city!.id,
            cityName: _city!.name,
            categoryId: _categoryId!,
            categoryName: _categoryName ?? '',
            whatsapp: wa,
            telegram: tg,
          );
      ref.read(myProductsPagedProvider.notifier).refresh();
      ref.read(productsPagedProvider.notifier).refresh();
      for (final s in ProductStatus.values) {
        ref.invalidate(myProductsByStatusProvider(s));
      }
      if (_isEdit) ref.invalidate(productDetailsProvider(widget.initial!.id));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.showSnack(context.tr(_isEdit ? 'adUpdated' : 'adPublished'),
          type: SnackType.success);
      setState(() => _dirty = false);
      if (_isEdit) {
        context.pop();
      } else {
        context.pushReplacement('/product/${product.id}', extra: product);
      }
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final quality = listingQuality(_asProduct());
    final left = _requiredLeft;
    final defaults = ref.watch(sellerDefaultsProvider);
    final recent =
        defaults.recentCategories.where((c) => c.$1 != _categoryId).toList();
    final phoneDigits = KgPhoneFormatter.digitsOf(_phone.text);

    Widget section(String title, {String? trailing, bool done = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 12),
          child: Row(
            children: [
              Flexible(child: Text(title, style: context.text.headlineSmall)),
              AnimatedScale(
                scale: done ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                        color: AppColors.success, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Text(trailing,
                    style: context.text.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return PopScope(
      canPop: !(_isEdit && _dirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.close_rounded), onPressed: _close),
          title: Text(context.tr(_isEdit
              ? 'editAd'
              : widget.template != null
                  ? 'newAdSimilar'
                  : 'newAd')),
          actions: [
            IconButton(
              tooltip: context.tr('preview'),
              icon: const Icon(Icons.visibility_outlined),
              onPressed: _showPreview,
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _ProgressStrip(
              score: quality.score,
              requiredLeft: left,
              nextTip: quality.tips.isEmpty
                  ? null
                  : context.tr(quality.tips.first.l10nKey),
              onTap: () {
                FocusScope.of(context).unfocus();
                showQualityChecklist(context, _asProduct());
              },
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (_draftBanner)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: const BoxDecoration(
                    gradient: AppColors.forestGradient,
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          color: AppColors.lime, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(context.tr('draftRestored'),
                            style: context.text.bodyMedium?.copyWith(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: _startOver,
                        child: Text(context.tr('startOver'),
                            style: const TextStyle(
                                color: AppColors.lime,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              section(context.tr('photoVideo'),
                  done: _photos >= 3,
                  trailing:
                      '$_photos/${AppConfig.maxPhotos} ${context.tr('photoShort')} · $_videos/${AppConfig.maxVideos} ${context.tr('videoShort')}'),
              SizedBox(
                height: 118,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, _, a) => ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.06).animate(a),
                      child: child),
                  itemCount: _media.length,
                  onReorder: (from, to) {
                    HapticFeedback.selectionClick();
                    if (to > from) to--;
                    _media.insert(to, _media.removeAt(from));
                    _changed();
                  },
                  header: _AddMediaTile(
                      onTap: _pickMedia, error: _submitted && _photos == 0),
                  itemBuilder: (_, i) {
                    final m = _media[i];
                    return ReorderableDelayedDragStartListener(
                      key: m.key,
                      index: i,
                      child: _MediaTile(
                        media: m,
                        isCover: i == _media.indexWhere((x) => !x.isVideo),
                        onTap: () => _mediaActions(i),
                        onRemove: () {
                          _media.removeAt(i);
                          _changed();
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(context.tr('reorderHint'),
                    style: context.text.bodySmall
                        ?.copyWith(color: p.textTertiary)),
              ),
              section(context.tr('aboutAd'),
                  done: _title.text.trim().length >= 12 && _categoryId != null),
              AppTextField(
                controller: _title,
                label: context.tr('title'),
                hint: context.tr('titleHint'),
                maxLength: AppConfig.titleMax,
                textCapitalization: TextCapitalization.sentences,
                validator: Validators.required(context),
              ),
              const SizedBox(height: 8),
              SelectField(
                label: context.tr('category'),
                placeholder: context.tr('chooseCategory'),
                value: _categoryName,
                icon: Icons.category_rounded,
                onTap: _pickCategory,
                errorText: _submitted && _categoryId == null
                    ? context.tr('vRequired')
                    : null,
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 10),
                _ChipRow(
                  label: context.tr('recentCats'),
                  children: [
                    for (final (id, name) in recent)
                      _QuickChip(
                          icon: Icons.history_rounded,
                          label: name.split(' · ').last,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _setCategory(id, name);
                          }),
                  ],
                ),
              ],
              section(context.tr('price'),
                  done: _currency.isPriceless ||
                      (int.tryParse(_price.text) ?? 0) > 0),
              if (_giveaway)
                const _GiveawayNote()
              else ...[
                AppSegmented<Currency>(
                  items: Currency.priced,
                  value: _currency,
                  labelOf: (c) => c == Currency.negotiable
                      ? context.tr('negotiable')
                      : c.api,
                  onChanged: (c) {
                    _currency = c;
                    _changed();
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: _currency == Currency.negotiable
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              AppTextField(
                                controller: _price,
                                hint: '0',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12)
                                ],
                                prefixIcon: _currency == Currency.usd
                                    ? Icons.attach_money_rounded
                                    : Icons.payments_rounded,
                                suffix: Padding(
                                  padding:
                                      const EdgeInsets.only(right: 16, top: 18),
                                  child: Text(
                                      _currency == Currency.usd
                                          ? 'USD'
                                          : context.tr('som'),
                                      style: context.text.labelLarge
                                          ?.copyWith(color: p.textTertiary)),
                                ),
                                validator: (v) => !_currency.isPriceless &&
                                        (v == null || v.isEmpty || v == '0')
                                    ? context.tr('vPrice')
                                    : null,
                              ),
                              if (_categoryId != null)
                                Consumer(builder: (_, r, __) {
                                  final hint = r
                                      .watch(priceHintProvider(
                                          (_categoryId!, _currency)))
                                      .valueOrNull;
                                  return hint == null
                                      ? const SizedBox(width: double.infinity)
                                      : PriceHintLine(
                                          hint: hint,
                                          currency: _currency,
                                          onUse: () => _price.text =
                                              hint.median.toStringAsFixed(0));
                                }),
                            ],
                          ),
                        ),
                ),
              ],
              if (!_giveaway) ...[
                section(context.tr('variants'),
                    done: _options.isNotEmpty &&
                        _options.every((o) => o.values.isNotEmpty)),
                OptionsEditor(
                  options: _options,
                  onChanged: (o) {
                    _options = o;
                    _changed();
                  },
                ),
              ],
              section(context.tr('location'),
                  done: _region != null && _city != null),
              SelectField(
                label: context.tr('region'),
                placeholder: context.tr('chooseRegion'),
                value: _region?.name,
                icon: Icons.map_rounded,
                onTap: _pickRegion,
                errorText: _submitted && _region == null
                    ? context.tr('vRequired')
                    : null,
              ),
              const SizedBox(height: 12),
              SelectField(
                label: context.tr('city'),
                placeholder: _region == null
                    ? context.tr('chooseRegionFirst')
                    : context.tr('chooseCity'),
                value: _city?.name,
                icon: Icons.location_city_rounded,
                enabled: _region != null,
                onTap: _pickCity,
                errorText: _submitted && _region != null && _city == null
                    ? context.tr('vRequired')
                    : null,
              ),
              section(context.tr('description'),
                  done: _desc.text.trim().length >= 80),
              AppTextField(
                controller: _desc,
                hint: context.tr('descriptionHint'),
                maxLines: 8,
                minLines: 5,
                maxLength: AppConfig.descriptionMax,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().length < 10)
                    ? context.tr('vDescription')
                    : null,
              ),
              _ChipRow(
                label: context.tr('quickPhrases'),
                children: [
                  for (final k in _phrases)
                    if (!_desc.text.contains(context.tr(k)))
                      _QuickChip(
                          icon: Icons.add_rounded,
                          label: context.tr(k),
                          onTap: () => _appendPhrase(context.tr(k))),
                ],
              ),
              section(context.tr('contacts'),
                  done:
                      _wa.text.trim().isNotEmpty || _tg.text.trim().isNotEmpty),
              AppTextField(
                controller: _phone,
                label: context.tr('phone'),
                prefixText: '+996 ',
                hint: '700 123 456',
                keyboardType: TextInputType.phone,
                inputFormatters: [KgPhoneFormatter()],
                validator: Validators.phone(context),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _wa,
                label: '${context.tr('whatsapp')} · ${context.tr('optional')}',
                hint: 'https://wa.me/996700123456',
                prefixIcon: Icons.chat_rounded,
                keyboardType: TextInputType.url,
                validator: Validators.optionalUrl(
                    context, ['https://wa.me/', 'https://api.whatsapp.com/']),
              ),
              if (_wa.text.trim().isEmpty && phoneDigits.length == 9)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _QuickChip(
                      icon: Icons.bolt_rounded,
                      label: context.tr('waFromPhone'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _wa.text = 'https://wa.me/996$phoneDigits';
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _tg,
                label: '${context.tr('telegram')} · ${context.tr('optional')}',
                hint: 'https://t.me/username',
                prefixIcon: Icons.send_rounded,
                keyboardType: TextInputType.url,
                validator:
                    Validators.optionalUrl(context, ['https://t.me/', '@']),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.paddingOf(context).bottom + 12),
          decoration: BoxDecoration(
              color: p.bg, border: Border(top: BorderSide(color: p.border))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_progress != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_progress!,
                      style: context.text.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              Row(
                children: [
                  _OutlineSquare(
                      icon: Icons.visibility_outlined, onTap: _showPreview),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: context.tr(_isEdit ? 'save' : 'publish'),
                      icon: _isEdit
                          ? Icons.check_rounded
                          : Icons.rocket_launch_rounded,
                      loading: _saving,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Вместо поля цены в разделе «Отдам даром».
class _GiveawayNote extends StatelessWidget {
  const _GiveawayNote();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lime.withValues(alpha: context.isDark ? 0.14 : 0.3),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                gradient: AppColors.limeGradient, shape: BoxShape.circle),
            child: const Icon(Icons.volunteer_activism_rounded,
                color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('free'), style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(context.tr('giveawayPriceNote'),
                    style: context.text.bodySmall
                        ?.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Полоса под AppBar: качество + сколько обязательного осталось.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.score,
    required this.requiredLeft,
    required this.nextTip,
    required this.onTap,
  });
  final int score;
  final int requiredLeft;
  final String? nextTip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ready = requiredLeft == 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
        child: Row(
          children: [
            QualityRing(score: score, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      ready
                          ? context.tr('readyToPublish')
                          : context
                              .tr('requiredLeft')
                              .replaceAll('{n}', '$requiredLeft'),
                      key: ValueKey(requiredLeft),
                      style: context.text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ready ? AppColors.success : p.text),
                    ),
                  ),
                  if (nextTip != null)
                    Text(nextTip!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: p.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.checklist_rounded, color: p.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label.toUpperCase(),
              style: context.text.labelSmall
                  ?.copyWith(color: p.textTertiary, letterSpacing: 1.2)),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 11, 7),
        decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: p.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium
                      ?.copyWith(color: p.text, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineSquare extends StatelessWidget {
  const _OutlineSquare({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: p.border),
            boxShadow: AppShadows.soft(p.shadow, lift: 0.4)),
        child: Icon(icon, color: p.text),
      ),
    );
  }
}

class _AddMediaTile extends StatelessWidget {
  const _AddMediaTile({required this.onTap, required this.error});
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Pressable(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorder(
              color: error
                  ? AppColors.danger
                  : AppColors.primary.withValues(alpha: 0.6)),
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: (error ? AppColors.danger : AppColors.primary)
                  .withValues(alpha: 0.06),
              borderRadius: AppRadius.mdAll,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(context.tr('add'),
                    style: context.text.labelMedium?.copyWith(
                        color: error ? AppColors.danger : p.text,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile(
      {required this.media,
      required this.isCover,
      required this.onTap,
      required this.onRemove});
  final _DraftMedia media;
  final bool isCover;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final showImage = !media.isVideo || media.uploaded?.thumbnailUrl != null;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 112,
          height: 112,
          child: ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showImage)
                  AppImage(media.preview)
                else
                  Container(
                    decoration:
                        const BoxDecoration(gradient: AppColors.leafGradient),
                    child: const Icon(Icons.movie_rounded,
                        color: Colors.white, size: 36),
                  ),
                if (media.isVideo)
                  const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 34)),
                if (isCover)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(
                          color: AppColors.lime, borderRadius: AppRadius.mdAll),
                      child: Text(context.tr('cover'),
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(AppRadius.md)));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
