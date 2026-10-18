import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_palette.dart';

class ShimmerWrap extends StatelessWidget {
  const ShimmerWrap({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Shimmer.fromColors(
      baseColor: p.shimmerBase,
      highlightColor: p.shimmerHighlight,
      period: const Duration(milliseconds: 1300),
      child: child,
    );
  }
}

class Bone extends StatelessWidget {
  const Bone(
      {super.key,
      this.width,
      this.height = 14,
      this.radius = 12,
      this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
        width: circle ? height : width,
        height: height,
        decoration: BoxDecoration(
          color: context.palette.shimmerBase,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
        ),
      );
}

class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 22,
        crossAxisSpacing: 12,
        childCount: count,
        itemBuilder: (_, i) => const ShimmerWrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                  aspectRatio: 0.8,
                  child: Bone(
                      width: double.infinity,
                      height: double.infinity,
                      radius: 22)),
              SizedBox(height: 10),
              Bone(width: double.infinity, height: 12),
              SizedBox(height: 6),
              Bone(width: 110, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton(
      {super.key, this.count = 7, this.avatar = 56, this.square = false});
  final int count;
  final double avatar;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: count,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: ShimmerWrap(
          child: Row(
            children: [
              Bone(height: avatar, width: avatar, circle: !square, radius: 18),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone(width: 140, height: 15),
                    SizedBox(height: 10),
                    Bone(width: double.infinity, height: 12),
                    SizedBox(height: 6),
                    Bone(width: 90, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
