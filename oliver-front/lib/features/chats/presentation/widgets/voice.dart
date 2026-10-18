import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/pressable.dart';
import '../../domain/chat.dart';

/// Один плеер на всё приложение: новое голосовое останавливает предыдущее.
class VoicePlayback extends ChangeNotifier {
  VoicePlayback._() {
    _player.onPositionChanged.listen((p) {
      position = p;
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      duration = d;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      playing = false;
      position = Duration.zero;
      notifyListeners();
    });
  }

  static final instance = VoicePlayback._();

  final _player = AudioPlayer();
  String? currentId;
  bool playing = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1;

  bool isCurrent(String id) => currentId == id;

  Future<void> toggle(String id, String source) async {
    try {
      if (currentId == id) {
        if (playing) {
          await _player.pause();
          playing = false;
        } else {
          await _player.resume();
          playing = true;
        }
        notifyListeners();
        return;
      }
      await _player.stop();
      currentId = id;
      position = Duration.zero;
      duration = Duration.zero;
      playing = true;
      notifyListeners();
      // Обычное воспроизведение через динамик, даже после записи.
      await _player.setAudioContext(AudioContextConfig(
              route: AudioContextConfigRoute.system, respectSilence: false)
          .build());
      await _player.setPlaybackRate(speed);
      await _player.play(source.startsWith('http')
          ? UrlSource(source)
          : DeviceFileSource(source.replaceFirst('file://', '')));
    } catch (_) {
      playing = false;
      notifyListeners();
    }
  }

  Future<void> seek(String id, double fraction) async {
    if (currentId != id || duration == Duration.zero) return;
    await _player.seek(duration * fraction.clamp(0.0, 1.0));
  }

  Future<void> cycleSpeed() async {
    speed = switch (speed) { 1.0 => 1.5, 1.5 => 2.0, _ => 1.0 };
    await _player.setPlaybackRate(speed);
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    playing = false;
    currentId = null;
    notifyListeners();
  }
}

/// Стабильная «волна» для сообщения: из сида, чтобы не хранить её на сервере.
List<double> waveformFor(String seed, int bars) {
  final rnd = Random(seed.hashCode);
  return List.generate(bars, (i) {
    final env = 0.55 + 0.45 * sin(i / bars * pi);
    return (0.18 + rnd.nextDouble() * 0.82) * env;
  });
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.bars,
    required this.progress,
    required this.active,
    required this.idle,
    this.height = 30,
  });

  final List<double> bars;
  final double progress;
  final Color active;
  final Color idle;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.fromHeight(height),
        painter: _WavePainter(bars, progress, active, idle),
      );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.bars, this.progress, this.active, this.idle);
  final List<double> bars;
  final double progress;
  final Color active;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final step = size.width / bars.length;
    final w = max(1.5, step * 0.55);
    for (var i = 0; i < bars.length; i++) {
      final h = max(3.0, bars[i] * size.height);
      final x = i * step + (step - w) / 2;
      final played = (i + 0.5) / bars.length <= progress;
      canvas.drawRect(
        Rect.fromLTWH(x, (size.height - h) / 2, w, h),
        Paint()..color = played ? active : idle,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) =>
      o.progress != progress || o.bars != bars || o.active != active;
}

/// Пузырь голосового сообщения.
class VoiceBubble extends StatelessWidget {
  const VoiceBubble({super.key, required this.message, required this.mine});
  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = message;
    final source = m.mediaUrl ?? m.localPath ?? '';
    final total = int.tryParse(m.content) ?? 0;
    final fg = mine ? AppColors.cream : p.text;
    final bars = waveformFor(m.mediaUrl ?? m.id, 34);
    final pb = VoicePlayback.instance;

    return ListenableBuilder(
      listenable: pb,
      builder: (context, _) {
        final current = pb.isCurrent(m.id);
        final playing = current && pb.playing;
        final dur = current && pb.duration > Duration.zero
            ? pb.duration
            : Duration(seconds: total);
        final progress = current && dur.inMilliseconds > 0
            ? pb.position.inMilliseconds / dur.inMilliseconds
            : 0.0;
        final shown = current && pb.position > Duration.zero
            ? pb.position.inSeconds
            : total;
        return Container(
          width: min(280, MediaQuery.sizeOf(context).width * 0.72),
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : p.surface,
            border: mine ? null : Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Pressable(
                scale: 0.88,
                onTap: m.status == MessageStatus.sending || source.isEmpty
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        pb.toggle(m.id, source);
                      },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: mine ? AppColors.lime : AppColors.primary,
                      shape: BoxShape.circle),
                  child: m.status == MessageStatus.sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: AppColors.ink))
                      : AnimatedSwitcher(
                          duration: Motion.fast,
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(playing),
                            color: mine ? AppColors.ink : AppColors.cream,
                            size: 26,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) =>
                            pb.seek(m.id, d.localPosition.dx / c.maxWidth),
                        onHorizontalDragUpdate: (d) =>
                            pb.seek(m.id, d.localPosition.dx / c.maxWidth),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: progress),
                          duration: const Duration(milliseconds: 180),
                          builder: (_, v, __) => _Waveform(
                            bars: bars,
                            progress: v,
                            active: mine ? AppColors.lime : AppColors.primary,
                            idle: fg.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(formatVoiceDuration(shown),
                            style: TextStyle(
                                color: fg.withValues(alpha: 0.8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                        const Spacer(),
                        if (current)
                          GestureDetector(
                            onTap: pb.cycleSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: fg.withValues(alpha: 0.14),
                                  borderRadius: AppRadius.pillAll),
                              child: Text(
                                  '${pb.speed == pb.speed.roundToDouble() ? pb.speed.toInt() : pb.speed}x',
                                  style: TextStyle(
                                      color: fg,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(formatClock(m.createdAt),
                            style: TextStyle(
                                color: fg.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Панель записи: заменяет поле ввода, пока идёт запись.
class VoiceRecorderBar extends StatefulWidget {
  const VoiceRecorderBar(
      {super.key, required this.onCancel, required this.onSend});

  final VoidCallback onCancel;
  final void Function(String path, int seconds) onSend;

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar> {
  final _rec = AudioRecorder();
  final _levels = <double>[];
  StreamSubscription<Amplitude>? _amp;
  Timer? _timer;
  final _watch = Stopwatch();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await VoicePlayback.instance.stop();
      if (!await _rec.hasPermission()) {
        if (mounted) {
          context.showSnack(context.tr('micDenied'), type: SnackType.error);
          widget.onCancel();
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 44100,
            numChannels: 1),
        path: path,
      );
      HapticFeedback.mediumImpact();
      _watch.start();
      _started = true;
      _amp =
          _rec.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((a) {
        // dBFS (-60..0) → 0..1
        final v = ((a.current + 60) / 60).clamp(0.05, 1.0);
        setState(() {
          _levels.add(v);
          if (_levels.length > 60) _levels.removeAt(0);
        });
      });
      _timer = Timer.periodic(
          const Duration(milliseconds: 250), (_) => setState(() {}));
    } catch (_) {
      if (mounted) widget.onCancel();
    }
  }

  Future<void> _finish(bool send) async {
    _timer?.cancel();
    await _amp?.cancel();
    _watch.stop();
    final secs = _watch.elapsed.inMilliseconds / 1000;
    if (!_started) {
      widget.onCancel();
      return;
    }
    if (!send) {
      await _rec.cancel();
      HapticFeedback.lightImpact();
      widget.onCancel();
      return;
    }
    final path = await _rec.stop();
    if (path == null || secs < 0.8) {
      if (mounted) context.showSnack(context.tr('tooShort'));
      widget.onCancel();
      return;
    }
    HapticFeedback.lightImpact();
    widget.onSend(path, secs.round().clamp(1, 3600));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amp?.cancel();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final secs = _watch.elapsed.inSeconds;
    return Container(
      padding: EdgeInsets.fromLTRB(
          10, 8, 10, MediaQuery.paddingOf(context).bottom + 8),
      decoration: BoxDecoration(
          color: p.bg, border: Border(top: BorderSide(color: p.border))),
      child: Row(
        children: [
          Pressable(
            onTap: () => _finish(false),
            scale: 0.88,
            child: Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(color: p.surface2, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: p.surface2, borderRadius: AppRadius.pillAll),
              child: Row(
                children: [
                  Breathing(
                    period: const Duration(milliseconds: 700),
                    builder: (_, t, __) => Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color:
                              AppColors.danger.withValues(alpha: 0.4 + 0.6 * t),
                          shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatVoiceDuration(secs),
                      style: context.text.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Waveform(
                      bars: [
                        ...List.filled(max(0, 60 - _levels.length), 0.05),
                        ..._levels
                      ],
                      progress: 1,
                      active: AppColors.primary,
                      idle: p.textTertiary,
                      height: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: () => _finish(true),
            scale: 0.85,
            child: Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: AppColors.ink, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
