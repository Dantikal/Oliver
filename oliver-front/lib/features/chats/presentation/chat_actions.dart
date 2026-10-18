import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/feedback.dart';
import '../../auth/domain/user.dart';
import '../data/chat_repositories.dart';

/// Открыть существующий или создать новый чат с пользователем.
Future<void> openChatWith(BuildContext context, WidgetRef ref, User peer,
    {String? productId}) async {
  try {
    final chatId = await ref
        .read(chatRepositoryProvider)
        .createOrGet(peerId: peer.id, productId: productId?.split('~').first);
    if (context.mounted) context.push('/chat/$chatId', extra: peer);
  } catch (e) {
    if (context.mounted) context.showError(e);
  }
}
