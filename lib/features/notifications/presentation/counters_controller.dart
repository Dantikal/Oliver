import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pagination/paged.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notification_repositories.dart';
import '../domain/notification.dart';

final countersProvider =
    NotifierProvider<CountersController, Counters>(CountersController.new);

class CountersController extends Notifier<Counters> {
  Timer? _timer;

  @override
  Counters build() {
    final status = ref.watch(authControllerProvider.select((s) => s.status));
    _timer?.cancel();
    if (status == AuthStatus.authenticated) {
      Future.microtask(refresh);
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    }
    ref.onDispose(() => _timer?.cancel());
    return const Counters();
  }

  Future<void> refresh() async {
    try {
      state = await ref.read(notificationRepositoryProvider).counters();
    } catch (_) {}
  }

  void decMessages(int n) => state = state.copyWith(
      unreadMessages: (state.unreadMessages - n).clamp(0, 1 << 30));

  void incMessages() =>
      state = state.copyWith(unreadMessages: state.unreadMessages + 1);

  void clearActivity() =>
      state = state.copyWith(newLikes: 0, unreadNotifications: 0);
}

final notificationsPagedProvider = StateNotifierProvider.autoDispose<
    PagedController<AppNotification>, PagedState<AppNotification>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return PagedController((page) => repo.list(page));
});
