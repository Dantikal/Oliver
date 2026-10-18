import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_image.dart';
import '../../domain/product.dart';
import '../../../../core/widgets/glass.dart';

/// Галерея фото и видео со свайпом и индикатором страниц.
class MediaGallery extends StatefulWidget {
  const MediaGallery(
      {super.key,
      required this.media,
      required this.heroTag,
      this.height = 420});

  final List<MediaItem> media;
  final String heroTag;
  final double height;

  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, a, __) => FadeTransition(
        opacity: a,
        child: _FullscreenViewer(media: widget.media, initial: _index),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: media.isEmpty ? 1 : media.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              if (media.isEmpty) return const AppImage(null);
              final m = media[i];
              final child = m.isVideo
                  ? VideoSlide(
                      url: m.url,
                      thumbnail: m.thumbnailUrl,
                      active: i == _index)
                  : GestureDetector(
                      onTap: _openFullscreen, child: AppImage(m.url));
              return i == 0 ? Hero(tag: widget.heroTag, child: child) : child;
            },
          ),
          // Затемнение сверху под кнопки и снизу под индикатор.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.22, 0.75, 1],
                  colors: [
                    Color(0x80000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x59000000)
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          if (media.length > 1)
            Positioned(
              bottom: 44,
              left: 0,
              right: 0,
              child: Center(
                child: PhotoGlass(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: SmoothPageIndicator(
                    controller: _page,
                    count: media.length,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 7,
                      dotWidth: 7,
                      spacing: 5,
                      expansionFactor: 3.2,
                      activeDotColor: AppColors.lime,
                      dotColor: Color(0x80FFFFFF),
                    ),
                  ),
                ),
              ),
            ),
          if (media.length > 1)
            Positioned(
              right: 16,
              bottom: 44,
              child: PhotoGlass(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text('${_index + 1}/${media.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class VideoSlide extends StatefulWidget {
  const VideoSlide(
      {super.key,
      required this.url,
      this.thumbnail,
      this.active = true,
      this.autoplay = false});
  final String url;
  final String? thumbnail;
  final bool active;
  final bool autoplay;

  @override
  State<VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<VideoSlide> {
  VideoPlayerController? _c;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) _play();
  }

  @override
  void didUpdateWidget(VideoSlide old) {
    super.didUpdateWidget(old);
    if (!widget.active) _c?.pause();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_c == null) {
      setState(() => _loading = true);
      final c = AppImage.isLocal(widget.url)
          ? VideoPlayerController.file(File(widget.url.toFileSafe()))
          : VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _c = c;
      try {
        await c.initialize();
        await c.setLooping(true);
        c.addListener(() {
          if (mounted) setState(() {});
        });
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    }
    final c = _c!;
    c.value.isPlaying ? c.pause() : c.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return GestureDetector(
      onTap: _play,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c)),
              )
            else if (widget.thumbnail != null)
              AppImage(widget.thumbnail),
            AnimatedOpacity(
              opacity: ready && c.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 42),
                ),
              ),
            ),
            if (ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                      playedColor: AppColors.leaf,
                      bufferedColor: Color(0x55FFFFFF)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String toFileSafe() => replaceFirst('file://', '');
}

class _FullscreenViewer extends StatefulWidget {
  const _FullscreenViewer({required this.media, required this.initial});
  final List<MediaItem> media;
  final int initial;

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  late final _page = PageController(initialPage: widget.initial);
  late int _i = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.media.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) {
              final m = widget.media[i];
              if (m.isVideo) {
                return VideoSlide(
                    url: m.url, thumbnail: m.thumbnailUrl, active: i == _i);
              }
              return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(child: AppImage(m.url, fit: BoxFit.contain)));
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15)),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Text('${_i + 1} / ${widget.media.length}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
