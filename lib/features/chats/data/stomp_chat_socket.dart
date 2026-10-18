import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/chat.dart';
import '../domain/chat_repository.dart';

/// Минимальный STOMP 1.2 клиент поверх web_socket_channel.
///
/// Backend: endpoint `/ws` (чистый WebSocket, без SockJS),
/// подписка `/topic/chats/{chatId}`, отправка `/app/chats/{chatId}/send`.
/// Тело события: `{ "event": "MESSAGE" | "READ" | "TYPING" | "DELIVERED", ... }`.
class StompChatSocket implements ChatSocket {
  StompChatSocket(this._storage);

  final TokenStorage _storage;
  final _events = StreamController<ChatEvent>.broadcast();
  final _subscriptions = <String>{};
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;
  Timer? _reconnect;
  Timer? _heartbeat;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    if (_channel != null) return;
    final token = await _storage.accessToken;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      await _channel!.ready;
      _sub = _channel!.stream
          .listen(_onData, onDone: _onClosed, onError: (_) => _onClosed());
      _frame('CONNECT', {
        'accept-version': '1.2',
        'host': Uri.parse(AppConfig.baseUrl).host,
        'heart-beat': '10000,10000',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _onClosed();
    }
  }

  void _frame(String command, Map<String, String> headers, [String body = '']) {
    final b = StringBuffer('$command\n');
    headers.forEach((k, v) => b.write('$k:$v\n'));
    b.write('\n$body\u0000');
    _channel?.sink.add(b.toString());
  }

  void _onData(dynamic data) {
    final raw = data.toString();
    if (raw.trim().isEmpty) return; // heart-beat
    for (final chunk in raw.split('\u0000')) {
      if (chunk.trim().isEmpty) continue;
      final sep = chunk.indexOf('\n\n');
      final head =
          (sep < 0 ? chunk : chunk.substring(0, sep)).trimLeft().split('\n');
      final body = sep < 0 ? '' : chunk.substring(sep + 2);
      final command = head.first.trim();
      if (command == 'CONNECTED') {
        _connected = true;
        for (final id in _subscriptions) {
          _subscribeFrame(id);
        }
        _heartbeat?.cancel();
        _heartbeat = Timer.periodic(
            const Duration(seconds: 10), (_) => _channel?.sink.add('\n'));
      } else if (command == 'MESSAGE') {
        _handle(body);
      }
    }
  }

  void _handle(String body) {
    try {
      final j = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final chatId = j['chatId'].toString();
      switch ('${j['event'] ?? j['type']}'.toUpperCase()) {
        case 'READ':
          _events.add(ReadEvent(chatId, j['userId'].toString()));
        case 'TYPING':
          _events.add(TypingEvent(
              chatId, j['userId'].toString(), (j['typing'] ?? true) as bool));
        case 'DELIVERED':
          _events.add(DeliveredEvent(chatId, j['messageId'].toString()));
        default:
          final m = j['message'] is Map
              ? Map<String, dynamic>.from(j['message'] as Map)
              : j;
          _events.add(MessageEvent(chatId, Message.fromJson(m),
              clientId: j['clientId']?.toString()));
      }
    } catch (e) {
      debugPrint('WS parse error: $e');
    }
  }

  void _onClosed() {
    _connected = false;
    _heartbeat?.cancel();
    _sub?.cancel();
    _channel = null;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), connect);
  }

  void _subscribeFrame(String chatId) => _frame('SUBSCRIBE', {
        'id': 'sub-$chatId',
        'destination': '/topic/chats/$chatId',
        'ack': 'auto'
      });

  @override
  void subscribe(String chatId) {
    if (_subscriptions.add(chatId) && _connected) _subscribeFrame(chatId);
  }

  @override
  void unsubscribe(String chatId) {
    if (_subscriptions.remove(chatId) && _connected) {
      _frame('UNSUBSCRIBE', {'id': 'sub-$chatId'});
    }
  }

  @override
  bool send(String chatId,
      {required String clientId,
      required MessageType type,
      required String content,
      String? mediaUrl}) {
    if (!_connected) return false;
    _frame(
      'SEND',
      {
        'destination': '/app/chats/$chatId/send',
        'content-type': 'application/json'
      },
      jsonEncode({
        'clientId': clientId,
        'type': type.api,
        'content': content,
        'mediaUrl': mediaUrl
      }),
    );
    return true;
  }

  @override
  void typing(String chatId, bool isTyping) {
    if (!_connected) return;
    _frame(
        'SEND',
        {
          'destination': '/app/chats/$chatId/typing',
          'content-type': 'application/json'
        },
        jsonEncode({'typing': isTyping}));
  }

  @override
  void dispose() {
    _reconnect?.cancel();
    _heartbeat?.cancel();
    if (_connected) _frame('DISCONNECT', {});
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
  }
}
