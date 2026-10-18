import '../../auth/domain/user.dart';

enum MessageType {
  text('TEXT'),
  image('IMAGE'),
  video('VIDEO'),

  /// Голосовое: файл в mediaUrl, длительность в секундах — в content.
  voice('VOICE');

  const MessageType(this.api);
  final String api;

  static MessageType fromApi(String? v) =>
      MessageType.values.firstWhere((t) => t.api == v?.toUpperCase(),
          orElse: () => MessageType.text);
}

enum MessageStatus { sending, sent, delivered, read, failed }

MessageStatus _statusFromApi(String? v) => switch (v?.toUpperCase()) {
      'DELIVERED' => MessageStatus.delivered,
      'READ' => MessageStatus.read,
      _ => MessageStatus.sent,
    };

class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.content,
    this.mediaUrl,
    this.localPath,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String content;
  final String? mediaUrl;
  final String? localPath;
  final DateTime createdAt;
  final MessageStatus status;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'].toString(),
        chatId: j['chatId'].toString(),
        senderId: j['senderId'].toString(),
        type: MessageType.fromApi(j['type'] as String?),
        content: (j['content'] ?? '') as String,
        mediaUrl: j['mediaUrl'] as String?,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        status: _statusFromApi(j['status'] as String?),
      );

  Message copyWith({String? id, MessageStatus? status, String? mediaUrl}) =>
      Message(
        id: id ?? this.id,
        chatId: chatId,
        senderId: senderId,
        type: type,
        content: content,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        localPath: localPath,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}

class ChatSummary {
  const ChatSummary({
    required this.chatId,
    required this.peer,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    this.isOnline = false,
    this.productId,
    this.productTitle,
    this.productImage,
  });

  final String chatId;
  final User peer;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final bool isOnline;
  final String? productId;
  final String? productTitle;
  final String? productImage;

  factory ChatSummary.fromJson(Map<String, dynamic> j) {
    final product = j['product'] is Map ? j['product'] as Map : null;
    return ChatSummary(
      chatId: j['chatId'].toString(),
      peer: User.fromJson(Map<String, dynamic>.from(j['peer'] as Map)),
      lastMessage: j['lastMessage'] is Map
          ? Message.fromJson(Map<String, dynamic>.from(j['lastMessage'] as Map))
          : null,
      unreadCount: (j['unreadCount'] ?? 0) as int,
      updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.now(),
      isOnline: (j['peer']?['online'] ?? false) as bool,
      productId: product?['id']?.toString(),
      productTitle: product?['title'] as String?,
      productImage: product?['imageUrl'] as String?,
    );
  }

  ChatSummary copyWith(
          {Message? lastMessage, int? unreadCount, DateTime? updatedAt}) =>
      ChatSummary(
        chatId: chatId,
        peer: peer,
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
        updatedAt: updatedAt ?? this.updatedAt,
        isOnline: isOnline,
        productId: productId,
        productTitle: productTitle,
        productImage: productImage,
      );
}

/// События WebSocket (STOMP /topic/chats/{chatId}).
sealed class ChatEvent {
  const ChatEvent(this.chatId);
  final String chatId;
}

class MessageEvent extends ChatEvent {
  const MessageEvent(super.chatId, this.message, {this.clientId});
  final Message message;

  /// Идентификатор оптимистичного сообщения, если это эхо нашего же сообщения.
  final String? clientId;
}

class ReadEvent extends ChatEvent {
  const ReadEvent(super.chatId, this.readerId);
  final String readerId;
}

class DeliveredEvent extends ChatEvent {
  const DeliveredEvent(super.chatId, this.messageId);
  final String messageId;
}

class TypingEvent extends ChatEvent {
  const TypingEvent(super.chatId, this.userId, this.isTyping);
  final String userId;
  final bool isTyping;
}
