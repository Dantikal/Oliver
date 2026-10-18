import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/storage/prefs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/pressable.dart';

/// Готовые обложки в палитре бренда.
enum CoverPreset { forest, olive, lime, paper, night, sage }

/// Обложка профиля: готовый узор или своё фото.
class ProfileCover {
  const ProfileCover.preset(this.preset) : photoPath = null;
  const ProfileCover.photo(String this.photoPath) : preset = CoverPreset.forest;

  final CoverPreset preset;
  final String? photoPath;

  bool get isPhoto => photoPath != null;

  /// Обложка «по умолчанию» для чужого профиля — стабильная по id.
  factory ProfileCover.forUser(String id) => ProfileCover.preset(
      CoverPreset.values[id.hashCode.abs() % CoverPreset.values.length]);

  String encode() => isPhoto ? 'photo:$photoPath' : 'preset:${preset.name}';

  static ProfileCover decode(String? v) {
    if (v != null && v.startsWith('photo:')) {
      final path = v.substring(6);
      if (File(path).existsSync()) return ProfileCover.photo(path);
    }
    if (v != null && v.startsWith('preset:')) {
      final name = v.substring(7);
      for (final p in CoverPreset.values) {
        if (p.name == name) return ProfileCover.preset(p);
      }
    }
    return const ProfileCover.preset(CoverPreset.forest);
  }
}

/// Обложка своего профиля. Пока хранится на устройстве.
final profileCoverProvider =
    NotifierProvider<ProfileCoverNotifier, ProfileCover>(
        ProfileCoverNotifier.new);

class ProfileCoverNotifier extends Notifier<ProfileCover> {
  static const _key = 'profile_cover';

  @override
  ProfileCover build() =>
      ProfileCover.decode(ref.read(sharedPrefsProvider).getString(_key));

  void set(ProfileCover cover) {
    state = cover;
    ref.read(sharedPrefsProvider).setString(_key, cover.encode());
  }

  /// Копирует фото в документы приложения: временные файлы iOS может удалить.
  Future<void> setPhoto(String pickedPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = pickedPath.split('.').last;
    final dest =
        '${dir.path}/profile_cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(pickedPath).copy(dest);
    final old = state.photoPath;
    set(ProfileCover.photo(dest));
    if (old != null && old != dest) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
  }
}

/// Рисует обложку на всю доступную площадь. Пресеты — живой mesh-градиент.
class CoverArt extends StatefulWidget {
  const CoverArt({super.key, required this.cover, this.animate = true});
  final ProfileCover cover;

  /// В превью-плитках выбора обложки анимация не нужна.
  final bool animate;

  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.cover;
    if (cover.isPhoto) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Image.file(File(cover.photoPath!), fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x33000000)
                ],
              ),
            ),
          ),
        ],
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => SizedBox.expand(
            child: CustomPaint(
                painter: _CoverPainter(cover.preset, _c.value * 2 * pi))),
      ),
    );
  }
}

/// Цвета пресета: подложка и три пятна.
({Color base, List<Color> blobs}) _coverColors(CoverPreset p) => switch (p) {
      CoverPreset.forest => (
          base: AppColors.forest,
          blobs: const [AppColors.primary, AppColors.lime, AppColors.teal]
        ),
      CoverPreset.olive => (
          base: const Color(0xFF3F5226),
          blobs: const [Color(0xFF8DA84A), Color(0xFFD8E27A), Color(0xFF5E8A34)]
        ),
      CoverPreset.lime => (
          base: const Color(0xFFA9D93B),
          blobs: const [Color(0xFFE9FF9A), AppColors.primary, Color(0xFF6CC24A)]
        ),
      CoverPreset.paper => (
          base: const Color(0xFFEDE6D6),
          blobs: const [Color(0xFFC9E8B0), Color(0xFFF6D9A8), Color(0xFF9CCB7E)]
        ),
      CoverPreset.night => (
          base: const Color(0xFF05080A),
          blobs: const [Color(0xFF1F5F4A), Color(0xFF3B2A6B), AppColors.lime]
        ),
      CoverPreset.sage => (
          base: const Color(0xFF7E9A72),
          blobs: const [Color(0xFFBFD8B0), Color(0xFF4F7A6A), Color(0xFFE3EBC8)]
        ),
    };

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.preset, this.t);
  final CoverPreset preset;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;
    final colors = _coverColors(preset);
    canvas.drawRect(rect, Paint()..color = colors.base);

    void blob(Color c, double cx, double cy, double r, double a) {
      final center = Offset(cx * w, cy * h);
      final radius = r * w;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            c.withValues(alpha: a),
            c.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final b = colors.blobs;
    blob(b[0], 0.15 + 0.12 * sin(t), 0.3 + 0.2 * cos(t), 0.75, 0.9);
    blob(b[1], 0.85 + 0.1 * cos(t * 1.4), 0.2 + 0.15 * sin(t), 0.55, 0.75);
    blob(b[2], 0.55 + 0.2 * sin(t * 0.7), 1.0 + 0.1 * cos(t * 2), 0.65, 0.8);

    // Стеклянные сферы: прозрачное тело, блик сверху-слева, тонкий ободок.
    void orb(double cx, double cy, double r) {
      final c = Offset(cx * w, cy * h);
      final rr = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.5),
              colors: [
                Colors.white.withValues(alpha: 0.38),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.14),
              ],
              stops: const [0, 0.6, 1],
            ).createShader(rr));
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.35));
    }

    orb(0.78 + 0.02 * sin(t), 0.46 + 0.05 * cos(t), w * 0.13);
    orb(0.64 + 0.03 * cos(t * 1.3), 0.78 + 0.04 * sin(t), w * 0.05);
    orb(0.92, 0.12 + 0.04 * sin(t * 2), w * 0.035);
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.preset != preset || old.t != t;
}

String coverName(BuildContext context, CoverPreset p) => context.tr(switch (p) {
      CoverPreset.forest => 'coverForest',
      CoverPreset.olive => 'coverOlive',
      CoverPreset.lime => 'coverLime',
      CoverPreset.paper => 'coverPaper',
      CoverPreset.night => 'coverNight',
      CoverPreset.sage => 'coverSage',
    });

/// Шторка выбора обложки: превью применяется сразу.
Future<void> showCoverPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final current = ref.watch(profileCoverProvider);
      final p = ctx.palette;
      Widget tile({
        required bool selected,
        required VoidCallback onTap,
        required Widget child,
        required String label,
      }) =>
          Pressable(
            onTap: onTap,
            scale: 0.95,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 74,
                  padding: EdgeInsets.all(selected ? 3 : 0),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                        color: selected ? AppColors.lime : p.border,
                        width: selected ? 3 : 1),
                  ),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          selected ? AppRadius.lg - 5 : AppRadius.lg - 1),
                      child: SizedBox.expand(child: child)),
                ),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ctx.text.labelMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600)),
              ],
            ),
          );

      Future<void> pickPhoto() async {
        try {
          final f = await ImagePicker().pickImage(
              source: ImageSource.gallery, maxWidth: 1800, imageQuality: 88);
          if (f == null) return;
          await ref.read(profileCoverProvider.notifier).setPhoto(f.path);
          HapticFeedback.lightImpact();
        } on PlatformException catch (e) {
          if (ctx.mounted) {
            ctx.showSnack(e.message ?? ctx.tr('errGeneric'),
                type: SnackType.error);
          }
        }
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('coverTitle'), style: ctx.text.headlineSmall),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
                children: [
                  for (final preset in CoverPreset.values)
                    tile(
                      selected: !current.isPhoto && current.preset == preset,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(profileCoverProvider.notifier)
                            .set(ProfileCover.preset(preset));
                      },
                      label: coverName(ctx, preset),
                      child: CoverArt(
                          cover: ProfileCover.preset(preset), animate: false),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Pressable(
                onTap: pickPhoto,
                scale: 0.97,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: p.surface2,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                        color: current.isPhoto ? AppColors.lime : p.border,
                        width: current.isPhoto ? 3 : 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: p.text),
                      const SizedBox(width: 10),
                      Text(ctx.tr('ownPhoto'), style: ctx.text.titleSmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}
