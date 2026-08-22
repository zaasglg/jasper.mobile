import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/workspaces/data/models/create_workspace_request.dart';
import 'package:jospar/features/workspaces/data/models/workspace_model.dart';
import 'package:jospar/features/workspaces/data/repositories/workspace_repository_impl.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('parses direct and nested workspace logo URLs', () {
    final direct = WorkspaceModel.fromJson(<String, dynamic>{
      'id': 'one',
      'name': 'Цифровизация',
      'logoUrl': '/uploads/workspaces/one.png',
    });
    final nested = WorkspaceModel.fromJson(<String, dynamic>{
      'id': 'two',
      'name': 'Продажи',
      'logo': <String, dynamic>{'url': 'https://cdn.jospar.me/two.png'},
    });

    expect(direct.logoUrl, 'https://jospar.me/uploads/workspaces/one.png');
    expect(nested.logoUrl, 'https://cdn.jospar.me/two.png');
  });

  test('preserves an embedded base64 workspace logo', () {
    const embeddedLogo = 'data:image/jpeg;base64,AQID';
    final workspace = WorkspaceModel.fromJson(<String, dynamic>{
      'id': 'one',
      'name': 'Цифровизация',
      'logoUrl': embeddedLogo,
    });

    expect(workspace.logoUrl, embeddedLogo);
  });

  test('serializes a create workspace request explicitly', () {
    const request = CreateWorkspaceRequest(name: 'Маркетинг', color: '#E45D70');

    expect(request.toJson(), <String, dynamic>{
      'name': 'Маркетинг',
      'color': '#E45D70',
    });
    expect(CreateWorkspaceRequest.fromJson(request.toJson()), request);
  });

  test('loads workspaces and selects the first workspace by default', () async {
    const workspaces = <WorkspaceModel>[
      WorkspaceModel(id: 'one', name: 'Цифровизация'),
      WorkspaceModel(id: 'two', name: 'Продажи'),
    ];
    final storage = WorkspaceSelectionStorage(const FlutterSecureStorage());
    final cubit = WorkspaceCubit(
      repository: _FakeWorkspaceRepository(workspaces),
      selectionStorage: storage,
    );

    await cubit.load();

    final state = cubit.state as WorkspaceLoaded;
    expect(state.workspaces, workspaces);
    expect(state.selected, workspaces.first);
    expect(await storage.read(), 'one');
    await cubit.close();
  });

  test('switches workspace and persists the selection', () async {
    const workspaces = <WorkspaceModel>[
      WorkspaceModel(id: 'one', name: 'Цифровизация'),
      WorkspaceModel(id: 'two', name: 'Продажи'),
    ];
    final storage = WorkspaceSelectionStorage(const FlutterSecureStorage());
    final cubit = WorkspaceCubit(
      repository: _FakeWorkspaceRepository(workspaces),
      selectionStorage: storage,
    );
    await cubit.load();

    await cubit.select(workspaces.last);

    expect((cubit.state as WorkspaceLoaded).selected, workspaces.last);
    expect(await storage.read(), 'two');
    await cubit.close();
  });

  test('creates, appends, selects, and persists a workspace', () async {
    const initial = WorkspaceModel(id: 'one', name: 'Цифровизация');
    const created = WorkspaceModel(
      id: 'two',
      name: 'Маркетинг',
      color: '#E45D70',
    );
    final repository = _FakeWorkspaceRepository(const <WorkspaceModel>[
      initial,
    ], createdWorkspace: created);
    final storage = WorkspaceSelectionStorage(const FlutterSecureStorage());
    final cubit = WorkspaceCubit(
      repository: repository,
      selectionStorage: storage,
    );
    await cubit.load();

    final result = await cubit.createWorkspace('  Маркетинг  ', '#E45D70');

    final state = cubit.state as WorkspaceLoaded;
    expect(result, isTrue);
    expect(repository.lastRequest?.name, 'Маркетинг');
    expect(state.workspaces, <WorkspaceModel>[initial, created]);
    expect(state.selected, created);
    expect(state.isCreating, isFalse);
    expect(await storage.read(), 'two');
    await cubit.close();
  });

  test('prevents duplicate workspace submissions', () async {
    final pending = Completer<WorkspaceModel>();
    final repository = _FakeWorkspaceRepository(const <WorkspaceModel>[
      WorkspaceModel(id: 'one', name: 'Основной'),
    ], pendingCreation: pending);
    final cubit = WorkspaceCubit(
      repository: repository,
      selectionStorage: WorkspaceSelectionStorage(const FlutterSecureStorage()),
    );
    await cubit.load();

    final first = cubit.createWorkspace('Новый', '#6D5FE0');
    final duplicate = await cubit.createWorkspace('Дубликат', '#3CAF78');

    expect(duplicate, isFalse);
    expect(repository.createCalls, 1);
    pending.complete(
      const WorkspaceModel(id: 'two', name: 'Новый', color: '#6D5FE0'),
    );
    expect(await first, isTrue);
    await cubit.close();
  });

  test('keeps workspaces and exposes a concise creation error', () async {
    const initial = WorkspaceModel(id: 'one', name: 'Основной');
    final cubit = WorkspaceCubit(
      repository: _FakeWorkspaceRepository(const <WorkspaceModel>[
        initial,
      ], creationError: const WorkspaceException('Название уже занято.')),
      selectionStorage: WorkspaceSelectionStorage(const FlutterSecureStorage()),
    );
    await cubit.load();

    final result = await cubit.createWorkspace('Основной', '#6D5FE0');

    final state = cubit.state as WorkspaceLoaded;
    expect(result, isFalse);
    expect(state.workspaces, const <WorkspaceModel>[initial]);
    expect(state.selected, initial);
    expect(state.isCreating, isFalse);
    expect(state.creationError, 'Название уже занято.');
    await cubit.close();
  });
}

class _FakeWorkspaceRepository implements WorkspaceRepository {
  _FakeWorkspaceRepository(
    this.workspaces, {
    this.createdWorkspace,
    this.pendingCreation,
    this.creationError,
  });

  final List<WorkspaceModel> workspaces;
  final WorkspaceModel? createdWorkspace;
  final Completer<WorkspaceModel>? pendingCreation;
  final WorkspaceException? creationError;
  int createCalls = 0;
  CreateWorkspaceRequest? lastRequest;

  @override
  Future<List<WorkspaceModel>> getWorkspaces() async => workspaces;

  @override
  Future<WorkspaceModel> createWorkspace(CreateWorkspaceRequest request) async {
    createCalls += 1;
    lastRequest = request;
    if (creationError != null) throw creationError!;
    if (pendingCreation != null) return pendingCreation!.future;
    return createdWorkspace ??
        WorkspaceModel(id: 'created', name: request.name, color: request.color);
  }
}
