import 'dart:async';
import 'dart:math';

import '../../../core/mock/mock_db.dart';
import '../domain/chat.dart';
import '../domain/chat_repository.dart';

/// Имитация real-time: доставка, прочтение, «печатает…» и ответ собеседника.
class MockChatSocket implements ChatSocket {
  final _db = MockDb.instance;
  final _events = StreamController<ChatEvent>.broadcast();
  final _rnd = Random();
  final _timers = <Timer>[];

  static const _replies = [
    'Хорошо, договорились 👍',
    'Да, ещё актуально!',
    'Могу скинуть ещё фото',
    'Когда вам удобно посмотреть?',
    'Окей, напишу вечером',
    'Торг небольшой возможен 🙂',
    'Рахмат! 🙏',
  ];

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  bool get isConnected => true;

  bool _seeded = false;

  /// Демо уведомлений: вскоре после входа кто-то пишет первым.
  @override
  Future<void> connect() async {
    if (_seeded || _db.chats.length < 2) return;
    _seeded = true;
    _later(20000, () {
      final chat = _db.chats[1];
      final m = Message(
        id: _db.nextId('msg'),
        chatId: chat.chatId,
        senderId: chat.peer.id,
        type: MessageType.text,
        content: 'Здравствуйте! Ещё продаёте? Могу забрать сегодня 🙂',
        createdAt: DateTime.now(),
      );
      _db.messages.putIfAbsent(chat.chatId, () => []).insert(0, m);
      _events.add(MessageEvent(chat.chatId, m));
    });
  }

  @override
  void subscribe(String chatId) {}

  @override
  void unsubscribe(String chatId) {}

  void _later(int ms, void Function() f) =>
      _timers.add(Timer(Duration(milliseconds: ms), () {
        if (!_events.isClosed) f();
      }));

  @override
  bool send(String chatId,
      {required String clientId,
      required MessageType type,
      required String content,
      String? mediaUrl}) {
    final m = Message(
      id: _db.nextId('msg'),
      chatId: chatId,
      senderId: MockDb.meId,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
    );
    _db.messages.putIfAbsent(chatId, () => []).insert(0, m);
    final peerId = _db.chats.firstWhere((c) => c.chatId == chatId).peer.id;

    _later(350, () => _events.add(MessageEvent(chatId, m, clientId: clientId)));
    _later(900, () => _events.add(DeliveredEvent(chatId, m.id)));
    _later(1900, () => _events.add(ReadEvent(chatId, peerId)));
    _later(2300, () => _events.add(TypingEvent(chatId, peerId, true)));
    _later(4200, () {
      _events.add(TypingEvent(chatId, peerId, false));
      final reply = Message(
        id: _db.nextId('msg'),
        chatId: chatId,
        senderId: peerId,
        type: MessageType.text,
        content: _replies[_rnd.nextInt(_replies.length)],
        createdAt: DateTime.now(),
      );
      _db.messages[chatId]!.insert(0, reply);
      _events.add(MessageEvent(chatId, reply));
    });
    return true;
  }

  @override
  void typing(String chatId, bool isTyping) {}

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _events.close();
  }
}
