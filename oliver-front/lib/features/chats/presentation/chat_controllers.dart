import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sound/sfx.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/counters_controller.dart';
import '../data/chat_repositories.dart';
import '../domain/chat.dart';

/// Список чатов, отсортированный по времени последнего сообщения.
final chatListProvider =
    AsyncNotifierProvider<ChatListController, List<ChatSummary>>(
        ChatListController.new);

class ChatListController extends AsyncNotifier<List<ChatSummary>> {
  @override
  Future<List<ChatSummary>> build() {
    ref.watch(authControllerProvider.select((s) => s.status));
    return ref.read(chatRepositoryProvider).chats();
  }

  Future<void> refresh() async {
    final r =
        await AsyncValue.guard(() => ref.read(chatRepositoryProvider).chats());
    if (r.hasError && state.hasValue) throw r.error!;
    state = r;
  }

  void onMessage(Message m, {required bool mine, required bool viewing}) {
    final list = state.valueOrNull;
    if (list == null) return;
    final i = list.indexWhere((c) => c.chatId == m.chatId);
    if (i < 0) return;
    final c = list[i];
    final updated = c.copyWith(
      lastMessage: m,
      updatedAt: m.createdAt,
      unreadCount: mine || viewing ? c.unreadCount : c.unreadCount + 1,
    );
    state = AsyncData([updated, ...list.where((x) => x.chatId != m.chatId)]);
  }

  void markRead(String chatId) {
    final list = state.valueOrNull;
    if (list == null) return;
    state = AsyncData([
      for (final c in list) c.chatId == chatId ? c.copyWith(unreadCount: 0) : c
    ]);
  }
}

class ChatRoomState {
  const ChatRoomState({
    this.messages = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.page = 0,
    this.error,
    this.peerTyping = false,
  });

  /// Новые сверху (для reverse ListView).
  final List<Message> messages;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int page;
  final Object? error;
  final bool peerTyping;

  ChatRoomState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? page,
    Object? error,
    bool clearError = false,
    bool? peerTyping,
  }) =>
      ChatRoomState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        error: clearError ? null : (error ?? this.error),
        peerTyping: peerTyping ?? this.peerTyping,
      );
}

final chatRoomProvider = NotifierProvider.autoDispose
    .family<ChatRoomController, ChatRoomState, String>(ChatRoomController.new);

class ChatRoomController
    extends AutoDisposeFamilyNotifier<ChatRoomState, String> {
  StreamSubscription<ChatEvent>? _sub;
  int _local = 0;
  String get _chatId => arg;
  String get _me => ref.read(currentUserProvider)?.id ?? '';

  @override
  ChatRoomState build(String chatId) {
    final socket = ref.read(chatSocketProvider);
    socket.connect().then((_) => socket.subscribe(chatId));
    _sub = socket.events.where((e) => e.chatId == chatId).listen(_onEvent);
    ref.onDispose(() {
      _sub?.cancel();
      socket.unsubscribe(chatId);
    });
    Future.microtask(load);
    return const ChatRoomState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final r = await ref.read(chatRepositoryProvider).messages(_chatId, 0);
      state = state.copyWith(
          messages: r.items, loading: false, hasMore: r.hasMore, page: 0);
      _markRead();
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final r = await ref
          .read(chatRepositoryProvider)
          .messages(_chatId, state.page + 1);
      state = state.copyWith(
        messages: [...state.messages, ...r.items],
        loadingMore: false,
        hasMore: r.hasMore,
        page: r.page,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  void _markRead() {
    final chats = ref.read(chatListProvider).valueOrNull ?? const [];
    final unread =
        chats.where((c) => c.chatId == _chatId).firstOrNull?.unreadCount ?? 0;
    ref.read(chatRepositoryProvider).markRead(_chatId).ignore();
    ref.read(chatListProvider.notifier).markRead(_chatId);
    if (unread > 0) ref.read(countersProvider.notifier).decMessages(unread);
  }

  void _onEvent(ChatEvent e) {
    switch (e) {
      case MessageEvent(:final message, :final clientId):
        final mine = message.senderId == _me;
        var list = state.messages;
        final idx =
            clientId == null ? -1 : list.indexWhere((m) => m.id == clientId);
        if (idx >= 0) {
          list = [...list]..[idx] =
              message.copyWith(status: MessageStatus.sent);
        } else if (!list.any((m) => m.id == message.id)) {
          list = [message, ...list];
        }
        state = state.copyWith(messages: list, peerTyping: mine ? null : false);
        if (!mine && clientId == null) Sfx.receive();
        ref
            .read(chatListProvider.notifier)
            .onMessage(message, mine: mine, viewing: true);
        if (!mine) ref.read(chatRepositoryProvider).markRead(_chatId).ignore();
      case DeliveredEvent(:final messageId):
        _setStatus((m) => m.id == messageId && m.status == MessageStatus.sent,
            MessageStatus.delivered);
      case ReadEvent(:final readerId):
        if (readerId != _me) {
          _setStatus(
              (m) =>
                  m.senderId == _me &&
                  m.status != MessageStatus.read &&
                  m.status != MessageStatus.sending,
              MessageStatus.read);
        }
      case TypingEvent(:final userId, :final isTyping):
        if (userId != _me) state = state.copyWith(peerTyping: isTyping);
    }
  }

  void _setStatus(bool Function(Message) where, MessageStatus s) {
    state = state.copyWith(messages: [
      for (final m in state.messages) where(m) ? m.copyWith(status: s) : m
    ]);
  }

  Future<void> sendText(String text) => _send(MessageType.text, text.trim());

  Future<void> sendMedia(String path, MessageType type,
      {String content = ''}) async {
    final clientId = 'local_${_local++}';
    final optimistic = Message(
      id: clientId,
      chatId: _chatId,
      senderId: _me,
      type: type,
      content: content,
      localPath: path,
      mediaUrl: path,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    state = state.copyWith(messages: [optimistic, ...state.messages]);
    Sfx.send();
    try {
      final url = await ref.read(chatRepositoryProvider).uploadMedia(path);
      await _deliver(clientId, type, content, url);
    } catch (_) {
      _setStatus((m) => m.id == clientId, MessageStatus.failed);
    }
  }

  Future<void> _send(MessageType type, String content) async {
    if (content.isEmpty) return;
    final clientId = 'local_${_local++}';
    final optimistic = Message(
      id: clientId,
      chatId: _chatId,
      senderId: _me,
      type: type,
      content: content,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    state = state.copyWith(messages: [optimistic, ...state.messages]);
    Sfx.send();
    ref
        .read(chatListProvider.notifier)
        .onMessage(optimistic, mine: true, viewing: true);
    await _deliver(clientId, type, content, null);
  }

  /// Через WebSocket, а если он недоступен — REST fallback.
  Future<void> _deliver(String clientId, MessageType type, String content,
      String? mediaUrl) async {
    final socket = ref.read(chatSocketProvider);
    final viaSocket = socket.send(_chatId,
        clientId: clientId, type: type, content: content, mediaUrl: mediaUrl);
    if (viaSocket) return;
    try {
      final m = await ref
          .read(chatRepositoryProvider)
          .send(_chatId, type: type, content: content, mediaUrl: mediaUrl);
      state = state.copyWith(
          messages: [for (final x in state.messages) x.id == clientId ? m : x]);
    } catch (_) {
      _setStatus((m) => m.id == clientId, MessageStatus.failed);
    }
  }

  Future<void> retry(Message m) async {
    state = state.copyWith(
        messages: state.messages.where((x) => x.id != m.id).toList());
    if (m.type == MessageType.text) {
      await sendText(m.content);
    } else if (m.localPath != null) {
      await sendMedia(m.localPath!, m.type, content: m.content);
    }
  }

  void typing(bool v) => ref.read(chatSocketProvider).typing(_chatId, v);
}
