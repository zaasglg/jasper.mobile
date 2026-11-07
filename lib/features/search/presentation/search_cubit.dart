import 'dart:async';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/search_repository.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.initial,
    this.results = const SearchResults(),
  });
  final String query;
  final SearchStatus status;
  final SearchResults results;
  @override
  List<Object?> get props => [query, status, results];
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this.repository, this.workspaceId) : super(const SearchState());
  final SearchRepository repository;
  final String workspaceId;
  Timer? _debounce;
  CancelToken? _request;
  int _revision = 0;

  void changeQuery(String value, {bool immediate = false}) {
    _debounce?.cancel();
    _request?.cancel('Search changed');
    final revision = ++_revision;
    final query = value.trim();
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }
    emit(SearchState(query: query, status: SearchStatus.loading));
    if (immediate) {
      unawaited(_search(query, revision));
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 300),
        () => _search(query, revision),
      );
    }
  }

  Future<void> _search(String query, int revision) async {
    final token = CancelToken();
    _request = token;
    try {
      final results = await repository.search(
        query,
        workspaceId,
        cancelToken: token,
      );
      if (!isClosed && revision == _revision) {
        emit(
          SearchState(
            query: query,
            status: results.isEmpty && results.failedSources.isNotEmpty
                ? SearchStatus.failure
                : SearchStatus.success,
            results: results,
          ),
        );
      }
    } catch (error) {
      if (!isClosed &&
          revision == _revision &&
          !(error is DioException && CancelToken.isCancel(error))) {
        emit(SearchState(query: query, status: SearchStatus.failure));
      }
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _request?.cancel('Search closed');
    _revision++;
    return super.close();
  }
}
