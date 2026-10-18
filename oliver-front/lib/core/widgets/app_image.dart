import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'skeletons.dart';

/// Сетевая (кэшируемая) или локальная картинка с shimmer-плейсхолдером.
class AppImage extends StatelessWidget {
  const AppImage(this.url,
      {super.key,
      this.fit = BoxFit.cover,
      this.radius = 0,
      this.width,
      this.height});

  final String? url;
  final BoxFit fit;
  final double radius;
  final double? width;
  final double? height;

  static bool isLocal(String u) => u.startsWith('/') || u.startsWith('file://');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = Container(
      width: width,
      height: height,
      color: p.surface2,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: p.textTertiary),
    );
    final u = url;
    Widget child;
    if (u == null || u.isEmpty) {
      child = fallback;
    } else if (isLocal(u)) {
      child = Image.file(File(u.replaceFirst('file://', '')),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => fallback);
    } else {
      child = CachedNetworkImage(
        imageUrl: u,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: const Duration(milliseconds: 260),
        placeholder: (_, __) => ShimmerWrap(
            child:
                Container(width: width, height: height, color: p.shimmerBase)),
        errorWidget: (_, __, ___) => fallback,
      );
    }
    return radius > 0
        ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: child)
        : child;
  }
}
