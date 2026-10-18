import '../../../core/pagination/paged.dart';
import 'chat.dart';

abstract class ChatRepository {
  Future<List<ChatSummary>> chats();
  Future<String> createOrGet({required String peerId, String? productId});
  Future<PageResult<Message>> messages(String chatId, int page);
  Future<Message> send(String chatId,
      {required MessageType type, required String content, String? mediaUrl});
  Future<void> markRead(String chatId);
  Future<String> uploadMedia(String path);
}

/// Real-time канал. Реализации: STOMP поверх WebSocket и mock.
abstract class ChatSocket {
  Stream<ChatEvent> get events;
  Future<void> connect();
  void subscribe(String chatId);
  void unsubscribe(String chatId);
  bool get isConnected;

  /// Отправка в /app/chats/{chatId}/send. Возвращает false, если сокет недоступен.
  bool send(String chatId,
      {required String clientId,
      required MessageType type,
      required String content,
      String? mediaUrl});
  void typing(String chatId, bool isTyping);
  void dispose();
}
