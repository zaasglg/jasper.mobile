import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/storage_scope.dart';
import '../domain/entities/storage_item.dart';
import '../domain/entities/storage_summary.dart';
import '../domain/entities/storage_analysis_result.dart';
import '../domain/entities/storage_enums.dart';
import '../domain/storage_repository.dart';

class StorageState extends Equatable {
  const StorageState({
    this.items = const [],
    this.favorites = const {},
    this.summaries = const [],
    this.summaryTotal = 0,
    this.loading = true,
    this.loadingSummaries = false,
    this.busy = false,
    this.progress = '',
    this.userId = '',
    this.error,
  });
  final List<StorageItem> items;
  final Set<String> favorites;
  final List<StorageSummary> summaries;
  final int summaryTotal;
  final bool loading, loadingSummaries, busy;
  final String progress, userId;
  final String? error;
  StorageState copyWith({
    List<StorageItem>? items,
    Set<String>? favorites,
    List<StorageSummary>? summaries,
    int? summaryTotal,
    bool? loading,
    bool? loadingSummaries,
    bool? busy,
    String? progress,
    String? userId,
    String? error,
  }) => StorageState(
    items: items ?? this.items,
    favorites: favorites ?? this.favorites,
    summaries: summaries ?? this.summaries,
    summaryTotal: summaryTotal ?? this.summaryTotal,
    loading: loading ?? this.loading,
    loadingSummaries: loadingSummaries ?? this.loadingSummaries,
    busy: busy ?? this.busy,
    progress: progress ?? this.progress,
    userId: userId ?? this.userId,
    error: error,
  );
  @override
  List<Object?> get props => [
    items,
    favorites,
    summaries,
    summaryTotal,
    loading,
    loadingSummaries,
    busy,
    progress,
    userId,
    error,
  ];
}

class StorageCubit extends Cubit<StorageState> {
  StorageCubit(this.repository, this.scope) : super(const StorageState());
  final StorageRepository repository;
  final StorageScope scope;
  CancelToken? _loadToken;
  final _actionToken = CancelToken();
  static String errorText(Object error) {
    if (error is StorageException) return error.message;
    if (error is DioException) {
      if (error.response?.statusCode == 403) return 'Нет доступа к этим файлам';
      if (error.response?.statusCode == 404) {
        return 'Файл или источник больше недоступен';
      }
    }
    return 'Не удалось выполнить действие. Проверьте соединение и повторите.';
  }

  Future<void> load() async {
    _loadToken?.cancel();
    final token = _loadToken = CancelToken();
    emit(state.copyWith(loading: true));
    try {
      final items = await repository.load(scope, cancelToken: token);
      final favorites = scope.source == StorageSource.chat
          ? items.where((e) => e.favorited).map((e) => e.id).toSet()
          : await repository.favorites(scope);
      final userId = await repository.currentUserId();
      if (!isClosed && !token.isCancelled) {
        emit(
          state.copyWith(
            items: items,
            favorites: favorites,
            userId: userId,
            loading: false,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && !token.isCancelled) {
        emit(state.copyWith(loading: false, error: errorText(error)));
      }
    }
  }

  Future<void> loadSummaries({bool more = false}) async {
    if (state.loadingSummaries) return;
    emit(state.copyWith(loadingSummaries: true));
    try {
      final page = await repository.summaries(
        scope,
        more ? state.summaries.length : 0,
        cancelToken: _actionToken,
      );
      final items = {
        for (final item in [
          ...(more ? state.summaries : <StorageSummary>[]),
          ...page.items,
        ])
          item.id: item,
      };
      if (!isClosed) {
        emit(
          state.copyWith(
            summaries: items.values.toList(),
            summaryTotal: page.total,
            loadingSummaries: false,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(loadingSummaries: false, error: errorText(error)));
      }
    }
  }

  Future<void> favorite(StorageItem item) => action(() async {
    final selected = !state.favorites.contains(item.id);
    await repository.setFavorite(scope, item, selected);
    if (isClosed) return;
    final ids = {...state.favorites};
    selected ? ids.add(item.id) : ids.remove(item.id);
    emit(state.copyWith(favorites: ids));
  });
  Future<void> delete(StorageItem item) => action(() async {
    await repository.deleteMessage(scope, item);
    if (!isClosed) {
      emit(
        state.copyWith(
          items: state.items.where((e) => e.id != item.id).toList(),
          favorites: {...state.favorites}..remove(item.id),
        ),
      );
    }
  });
  Future<void> action(Future<void> Function() operation) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await operation();
      if (!isClosed) emit(state.copyWith(busy: false, progress: ''));
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(busy: false, progress: '', error: errorText(error)),
        );
      }
    }
  }

  Future<StorageAnalysisResult?> analyze(StorageItem item) async {
    StorageAnalysisResult? result;
    await action(() async {
      result = await repository.analyze(
        scope,
        item,
        cancelToken: _actionToken,
        onProgress: (value) {
          if (!isClosed) emit(state.copyWith(progress: value));
        },
      );
    });
    return result;
  }

  @override
  Future<void> close() {
    _loadToken?.cancel();
    _actionToken.cancel();
    return super.close();
  }
}
