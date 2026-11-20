import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/managed_space.dart';
import '../domain/entities/space_member.dart';
import '../domain/entities/space_kind.dart';
import '../domain/collaboration_repository.dart';

class CollaborationState extends Equatable {
  const CollaborationState({
    this.loading = true,
    this.saving = false,
    this.space,
    this.members = const [],
    this.error,
  });
  final bool loading;
  final bool saving;
  final ManagedSpace? space;
  final List<SpaceMember> members;
  final String? error;
  CollaborationState copyWith({
    bool? loading,
    bool? saving,
    ManagedSpace? space,
    List<SpaceMember>? members,
    String? error,
  }) => CollaborationState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    space: space ?? this.space,
    members: members ?? this.members,
    error: error,
  );
  @override
  List<Object?> get props => [loading, saving, space, members, error];
}

class CollaborationCubit extends Cubit<CollaborationState> {
  CollaborationCubit(this.repository, this.kind, this.id)
    : super(const CollaborationState());
  final CollaborationRepository repository;
  final SpaceKind kind;
  final String id;
  Future<void> load() async {
    emit(state.copyWith(loading: true));
    try {
      final space = await repository.getSpace(kind, id);
      if (isClosed) return;
      emit(state.copyWith(space: space));
      final people = await repository.members(kind, id);
      if (!isClosed) emit(state.copyWith(loading: false, members: people));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(loading: false, error: _message(e)));
    }
  }

  String _message(Object e) => e is CollaborationException
      ? e.message
      : 'Не удалось выполнить действие.';
  Future<bool> run(Future<void> Function() action, {bool reload = true}) async {
    if (state.saving) return false;
    emit(state.copyWith(saving: true));
    try {
      await action();
      if (isClosed) return true;
      if (reload) await load();
      if (!isClosed) emit(state.copyWith(saving: false, error: state.error));
      return state.error == null;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(saving: false, error: _message(e)));
      return false;
    }
  }
}
