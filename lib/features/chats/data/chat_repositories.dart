import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/mock/mock_db.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/pagination/paged.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/chat.dart';
import '../domain/chat_repository.dart';
import 'mock_chat_socket.dart';
import 'stomp_chat_socket.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => AppConfig.useMock
      ? MockChatRepository()
      : ChatRepositoryImpl(ref.watch(dioProvider)),
);

final chatSocketProvider = Provider<ChatSocket>((ref) {
  final ChatSocket socket = AppConfig.useMock
      ? MockChatSocket()
      : StompChatSocket(ref.watch(tokenStorageProvider));
  ref.onDispose(socket.dispose);
  return socket;
});

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<ChatSummary>> chats() => apiCall(() async {
        final r = await _dio.get('/chats');
        final list = (r.data as List)
            .map((e) =>
                ChatSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      });

  @override
  Future<String> createOrGet({required String peerId, String? productId}) =>
      apiCall(() async {
        final r = await _dio.post('/chats', data: {
          'peerId': peerId,
          if (productId != null) 'productId': productId
        });
        return r.data['chatId'].toString();
      });

  @override
  Future<PageResult<Message>> messages(String chatId, int page) =>
      apiCall(() async {
        final r = await _dio.get('/chats/$chatId/messages', queryParameters: {
          'page': page,
          'size': 30,
          'sort': 'createdAt,desc'
        });
        return PageResult.fromJson(r.data, Message.fromJson);
      });

  @override
  Future<Message> send(String chatId,
          {required MessageType type,
          required String content,
          String? mediaUrl}) =>
      apiCall(() async {
        final r = await _dio.post('/chats/$chatId/messages', data: {
          'type': type.api,
          'content': content,
          if (mediaUrl != null) 'mediaUrl': mediaUrl
        });
        return Message.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  @override
  Future<void> markRead(String chatId) =>
      apiCall(() => _dio.post('/chats/$chatId/read'));

  @override
  Future<String> uploadMedia(String path) => apiCall(() async {
        final form =
            FormData.fromMap({'file': await MultipartFile.fromFile(path)});
        final r = await _dio.post('/media/upload', data: form);
        return r.data['url'] as String;
      });
}

class MockChatRepository implements ChatRepository {
  final _db = MockDb.instance;

  @override
  Future<List<ChatSummary>> chats() async {
    await _db.delay();
    final list = _db.chats.map((c) {
      final last = _db.messages[c.chatId]?.firstOrNull;
      return last == null
          ? c
          : c.copyWith(lastMessage: last, updatedAt: last.createdAt);
    }).toList();
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<String> createOrGet(
      {required String peerId, String? productId}) async {
    await _db.delay(300, 600);
    final existing = _db.chats.where((c) => c.peer.id == peerId).firstOrNull;
    if (existing != null) return existing.chatId;
    final product = productId == null
        ? null
        : _db.products
            .where((p) => p.id == productId.split('~').first)
            .firstOrNull;
    final chat = ChatSummary(
      chatId: 'ch_$peerId',
      peer: _db.users[peerId]!,
      updatedAt: DateTime.now(),
      productId: product?.id,
      productTitle: product?.title,
      productImage: product?.coverUrl,
    );
    _db.chats.add(chat);
    _db.messages[chat.chatId] = [];
    return chat.chatId;
  }

  @override
  Future<PageResult<Message>> messages(String chatId, int page) async {
    await _db.delay(300, 600);
    return _db.page(_db.messages[chatId] ?? const [], page, 30);
  }

  @override
  Future<Message> send(String chatId,
      {required MessageType type,
      required String content,
      String? mediaUrl}) async {
    await _db.delay(200, 400);
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
    return m;
  }

  @override
  Future<void> markRead(String chatId) async {
    final i = _db.chats.indexWhere((c) => c.chatId == chatId);
    if (i >= 0) _db.chats[i] = _db.chats[i].copyWith(unreadCount: 0);
  }

  @override
  Future<String> uploadMedia(String path) async {
    await _db.delay(500, 900);
    return path;
  }
}
