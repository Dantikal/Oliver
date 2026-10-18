import 'package:audioplayers/audioplayers.dart';

/// Фирменные звуки интерфейса (assets/sounds, синтезированы под Oliver).
///
/// Каждый плеер со своим аудио-контекстом «ambient»: уважает беззвучный
/// режим iOS и не глушит чужую музыку. Глобальный контекст не трогаем —
/// голосовые сообщения должны играть и в беззвучном режиме.
class Sfx {
  Sfx._();

  /// Щелчки на нажатия (настройка «Звуки нажатий»).
  static bool ui = true;

  /// Отправка/входящие/уведомления (настройка «Звуки в чате»).
  static bool chat = true;

  static final _ctx = AudioContextConfig(respectSilence: true).build();
  static final _tapPool = <AudioPlayer>[];
  static int _tapNext = 0;
  static final _players = <String, AudioPlayer>{};
  static DateTime _lastTap = DateTime(0);

  static Future<AudioPlayer> _make(String name) async {
    final p = AudioPlayer();
    await p.setAudioContext(_ctx);
    await p.setPlayerMode(PlayerMode.lowLatency);
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setSource(AssetSource('sounds/$name.wav'));
    return p;
  }

  static Future<void> init() async {
    try {
      // Несколько плееров по кругу — быстрые тапы не обрывают друг друга.
      for (var i = 0; i < 3; i++) {
        _tapPool.add(await _make('tap'));
      }
      for (final n in const ['send', 'receive', 'notify', 'cart']) {
        _players[n] = await _make(n);
      }
    } catch (_) {
      // Звук — украшение: без него приложение работает как обычно.
    }
  }

  static void _play(AudioPlayer? p, double volume) {
    if (p == null) return;
    p.stop().then((_) => p.setVolume(volume)).then((_) => p.resume()).ignore();
  }

  static void tap() {
    if (!ui || _tapPool.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds < 45) return;
    _lastTap = now;
    _play(_tapPool[_tapNext++ % _tapPool.length], 0.45);
  }

  static void send() {
    if (chat) _play(_players['send'], 0.6);
  }

  static void receive() {
    if (chat) _play(_players['receive'], 0.6);
  }

  static void notify() {
    if (chat) _play(_players['notify'], 0.8);
  }

  static void cart() {
    if (ui) _play(_players['cart'], 0.6);
  }
}
