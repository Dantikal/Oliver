import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Страница из ответа `{ items, total, page, size }` (page — с нуля, как в Spring).
class PageResult<T> {
  const PageResult(
      {required this.items,
      required this.total,
      required this.page,
      required this.size});

  final List<T> items;
  final int total;
  final int page;
  final int size;

  bool get hasMore => (page + 1) * size < total;

  factory PageResult.fromJson(
      dynamic json, T Function(Map<String, dynamic>) parse) {
    if (json is List) {
      final items =
          json.map((e) => parse(Map<String, dynamic>.from(e as Map))).toList();
      return PageResult(
          items: items, total: items.length, page: 0, size: items.length);
    }
    final m = json as Map;
    final raw = (m['items'] ?? m['content'] ?? const []) as List;
    final items =
        raw.map((e) => parse(Map<String, dynamic>.from(e as Map))).toList();
    return PageResult(
      items: items,
      total: (m['total'] ?? m['totalElements'] ?? items.length) as int,
      page: (m['page'] ?? m['number'] ?? 0) as int,
      size: (m['size'] ?? items.length) as int,
    );
  }
}

class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.page = -1,
    this.total = 0,
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<T> items;
  final int page;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get isEmpty => !isLoading && error == null && items.isEmpty;

  PagedState<T> copyWith({
    List<T>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) =>
      PagedState<T>(
        items: items ?? this.items,
        page: page ?? this.page,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        loadMoreError:
            clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      );
}

/// Универсальный контроллер infinite-scroll пагинации.
class PagedController<T> extends StateNotifier<PagedState<T>> {
  PagedController(this._fetch) : super(PagedState<T>()) {
    refresh();
  }

  final Future<PageResult<T>> Function(int page) _fetch;
  int _generation = 0;

  Future<void> refresh() async {
    final gen = ++_generation;
    state = state.copyWith(
        isLoading: state.items.isEmpty,
        clearError: true,
        clearLoadMoreError: true);
    try {
      final r = await _fetch(0);
      if (!mounted || gen != _generation) return;
      state = PagedState<T>(
          items: r.items,
          page: 0,
          total: r.total,
          hasMore: r.hasMore,
          isLoading: false);
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.isLoading || s.isLoadingMore || !s.hasMore || s.error != null) return;
    final gen = _generation;
    state = s.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final r = await _fetch(s.page + 1);
      if (!mounted || gen != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...r.items],
        page: r.page,
        total: r.total,
        hasMore: r.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }

  void retryLoadMore() {
    state = state.copyWith(clearLoadMoreError: true);
    loadMore();
  }

  /// Локальная мутация (оптимистичные обновления: удаление, лайк и т.п.).
  void mutate(List<T> Function(List<T> items) f, {int totalDelta = 0}) {
    state =
        state.copyWith(items: f(state.items), total: state.total + totalDelta);
  }
}
