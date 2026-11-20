import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/managed_space.dart';
import '../domain/entities/space_member.dart';
import '../domain/entities/space_kind.dart';
import '../data/project_participants_repository.dart';
import '../domain/collaboration_repository.dart';

class ProjectParticipantsState extends Equatable {
  const ProjectParticipantsState({
    this.loading = true,
    this.saving = false,
    this.space,
    this.members = const [],
    this.invitations = const [],
    this.role = '',
    this.myId = '',
    this.error,
  });
  final bool loading;
  final bool saving;
  final ManagedSpace? space;
  final List<SpaceMember> members;
  final List<ProjectInvitation> invitations;
  final String role;
  final String myId;
  final String? error;
  List<String> get roles => assignableProjectRoles(role);
  List<String> get invitationRoles =>
      roles.where((role) => role != 'SUPER_ADMIN').toList();
  bool get canManage => roles.isNotEmpty;
  bool isLastAdministrator(SpaceMember member) =>
      (member.role == 'ADMIN' || member.role == 'SUPER_ADMIN') &&
      members
              .where((m) => m.role == 'ADMIN' || m.role == 'SUPER_ADMIN')
              .length <=
          1;
  bool canEdit(SpaceMember member) =>
      canManage &&
      member.role != 'OWNER' &&
      !member.isWorkspaceOwner &&
      member.userId != myId &&
      (role == 'SUPER_ADMIN' || member.role != 'SUPER_ADMIN');
  bool canRemove(SpaceMember member) =>
      canEdit(member) && !isLastAdministrator(member);
  List<String> rolesFor(SpaceMember member) => canEdit(member)
      ? roles
            .where((role) => role != 'EXECUTOR' || !isLastAdministrator(member))
            .toList()
      : [];
  @override
  List<Object?> get props => [
    loading,
    saving,
    space,
    members,
    invitations,
    role,
    myId,
    error,
  ];
}

class ProjectParticipantsCubit extends Cubit<ProjectParticipantsState> {
  ProjectParticipantsCubit(this.repository, this.id)
    : super(const ProjectParticipantsState());
  final ProjectParticipantsRepository repository;
  final String id;
  int _loadRevision = 0;
  String message(Object e) => e is CollaborationException
      ? e.message
      : 'Не удалось загрузить данные. Повторите попытку.';
  Future<void> load() async {
    if (isClosed) return;
    final revision = ++_loadRevision;
    final previous = state;
    emit(
      ProjectParticipantsState(
        loading: true,
        saving: previous.saving,
        space: previous.space,
        members: previous.members,
        invitations: previous.invitations,
        role: previous.role,
        myId: previous.myId,
      ),
    );
    try {
      final space = await repository.collaboration.getSpace(
        SpaceKind.project,
        id,
      );
      final people = await repository.members(id);
      final role = await repository.myRole(id);
      final myId = await repository.myId();
      if (!isClosed && revision == _loadRevision) {
        emit(
          ProjectParticipantsState(
            loading: false,
            saving: previous.saving,
            space: space,
            members: people.members,
            invitations: people.invitations,
            role: role,
            myId: myId,
          ),
        );
      }
    } catch (e) {
      if (!isClosed && revision == _loadRevision) {
        emit(
          ProjectParticipantsState(
            loading: false,
            saving: previous.saving,
            space: previous.space,
            members: previous.members,
            invitations: previous.invitations,
            role: previous.role,
            myId: previous.myId,
            error: message(e),
          ),
        );
      }
    }
  }

  Future<bool> mutate(Future<void> Function() action) async {
    if (state.saving || state.loading || !state.canManage) return false;
    final previous = state;
    emit(
      ProjectParticipantsState(
        loading: false,
        saving: true,
        space: state.space,
        members: state.members,
        invitations: state.invitations,
        role: state.role,
        myId: state.myId,
      ),
    );
    String? error;
    var saved = false;
    try {
      await action();
      saved = true;
      if (isClosed) return true;
      await load();
      error = state.error;
    } catch (e) {
      error = message(e);
    }
    if (!isClosed) {
      emit(
        ProjectParticipantsState(
          loading: false,
          space: state.space ?? previous.space,
          members: state.members,
          invitations: state.invitations,
          role: state.role,
          myId: state.myId,
          error: error,
        ),
      );
    }
    return saved;
  }
}
