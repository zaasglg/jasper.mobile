import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jospar/core/storage/workspace_selection_storage.dart';
import 'package:jospar/features/workspaces/domain/entities/create_workspace_request.dart';
import 'package:jospar/features/workspaces/domain/entities/workspace_model.dart';
import 'package:jospar/features/workspaces/data/repositories/workspace_repository_impl.dart';
import 'package:jospar/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  const multiWorkspaces = [
    WorkspaceModel(id: 'one', name: 'Первый'),
    WorkspaceModel(id: 'two', name: 'Второй'),
    WorkspaceModel(id: 'three', name: 'Третий'),
  ];

  for (final all in [false, true]) {
    for (final superseded in [false, true]) {
      test(
        'scope write failure restores storage (all: $all, superseded: $superseded)',
        () async {
          final storage = _FailingScopeStorage();
          final repository = _FakeWorkspaceRepository(multiWorkspaces);
          final cubit = WorkspaceCubit(
            repository: repository,
            selectionStorage: storage,
          );
          addTearDown(cubit.close);
          await cubit.load();
          if (all) await cubit.selectAll();
          storage.failNextScope = true;
          final first = cubit.select(multiWorkspaces[1]);
          await storage.writing.future;
          expect(await storage.read(), 'two');
          final newer = superseded
              ? cubit.select(multiWorkspaces[2])
              : Future<void>.value();
          storage.release.complete();
          await Future.wait([first, newer]);

          final expected = superseded ? 'three' : 'one';
          final state = cubit.state as WorkspaceLoaded;
          expect(state.selected?.id, expected);
          expect(await storage.read(), expected);
          expect(
            await storage.readScope(),
            superseded
                ? ['three']
                : all
                ? <String>[]
                : ['one'],
          );
          expect(state.allSelected, all && !superseded);
          expect(state.refreshError, superseded ? isNull : isNotNull);

          final restarted = WorkspaceCubit(
            repository: repository,
            selectionStorage: storage,
          );
          addTearDown(restarted.close);
          await restarted.load();
          expect((restarted.state as WorkspaceLoaded).selected?.id, expected);
          expect(
            (restarted.state as WorkspaceLoaded).effectiveSelectedIds,
            state.effectiveSelectedIds,
          );
        },
      );
    }
  }

  test(
    'refresh keeps the primary inside remaining selected workspaces',
    () async {
      final repository = _FakeWorkspaceRepository(multiWorkspaces);
      const storage = WorkspaceSelectionStorage(FlutterSecureStorage());
      final cubit = WorkspaceCubit(
        repository: repository,
        selectionStorage: storage,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.select(multiWorkspaces[1]);
      await cubit.toggle(multiWorkspaces[2]);
      repository.workspaces = [multiWorkspaces[0], multiWorkspaces[2]];
      await cubit.load(force: true);
      expect((cubit.state as WorkspaceLoaded).effectiveSelectedIds, {'three'});
      expect((cubit.state as WorkspaceLoaded).selected?.id, 'three');
      expect(await storage.read(), 'three');
      await cubit.selectAll();
      repository.workspaces = multiWorkspaces;
      await cubit.load(force: true);
      expect((cubit.state as WorkspaceLoaded).effectiveSelectedIds, {
        'one',
        'two',
        'three',
      });
    },
  );

  test(
    'multiple selection persists and cannot deselect the last workspace',
    () async {
      final repository = _FakeWorkspaceRepository(multiWorkspaces);
      const storage = WorkspaceSelectionStorage(FlutterSecureStorage());
      final cubit = WorkspaceCubit(
        repository: repository,
        selectionStorage: storage,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.toggle(multiWorkspaces[1]);
      expect((cubit.state as WorkspaceLoaded).effectiveSelectedIds, {
        'one',
        'two',
      });
      final restored = WorkspaceCubit(
        repository: repository,
        selectionStorage: storage,
      );
      addTearDown(restored.close);
      await restored.load();
      expect((restored.state as WorkspaceLoaded).effectiveSelectedIds, {
        'one',
        'two',
      });
      await restored.toggle(multiWorkspaces.first);
      await restored.toggle(multiWorkspaces[1]);
      expect((restored.state as WorkspaceLoaded).effectiveSelectedIds, {'two'});
      expect((restored.state as WorkspaceLoaded).selected?.id, 'two');
    },
  );

  test('all selects every workspace and survives restart', () async {
    final repository = _FakeWorkspaceRepository(multiWorkspaces);
    const storage = WorkspaceSelectionStorage(FlutterSecureStorage());
    final cubit = WorkspaceCubit(
      repository: repository,
      selectionStorage: storage,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.selectAll();
    expect((cubit.state as WorkspaceLoaded).areAllSelected, isTrue);
    final restored = WorkspaceCubit(
      repository: repository,
      selectionStorage: storage,
    );
    addTearDown(restored.close);
    await restored.load();
    expect((restored.state as WorkspaceLoaded).effectiveSelectedIds, {
      'one',
      'two',
      'three',
    });
    await restored.toggle(multiWorkspaces[1]);
    expect((restored.state as WorkspaceLoaded).effectiveSelectedIds, {
      'one',
      'three',
    });
    expect((restored.state as WorkspaceLoaded).areAllSelected, isFalse);
  });

  test(
    'failed multiple selection restores the previous persisted scope',
    () async {
      final storage = _DelayedSelectionStorage();
      final cubit = WorkspaceCubit(
        repository: _FakeWorkspaceRepository(multiWorkspaces),
        selectionStorage: storage,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.toggle(multiWorkspaces[1]);
      storage.failures.add('two');
      storage.release.complete();
      await cubit.toggle(multiWorkspaces.first);
      expect((cubit.state as WorkspaceLoaded).effectiveSelectedIds, {
        'one',
        'two',
      });
      expect(await storage.readScope(), unorderedEquals(['one', 'two']));
      expect(await storage.read(), 'one');
    },
  );

  test(
    'rapid selection back to the original workspace persists the last choice',
    () async {
      const workspaces = [
        WorkspaceModel(id: 'one', name: 'Первый'),
        WorkspaceModel(id: 'two', name: 'Второй'),
      ];
      final storage = _DelayedSelectionStorage();
      final cubit = WorkspaceCubit(
        repository: _FakeWorkspaceRepository(workspaces),
        selectionStorage: storage,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final first = cubit.select(workspaces.last);
      await storage.writing.future;
      final last = cubit.select(workspaces.first);
      storage.release.complete();
      await Future.wait([first, last]);
      expect((cubit.state as WorkspaceLoaded).selected?.id, 'one');
      expect(await storage.read(), 'one');
    },
  );

  test(
    'refresh cannot restore a choice superseded during persistence',
    () async {
      const workspaces = [
        WorkspaceModel(id: 'one', name: 'Первый'),
        WorkspaceModel(id: 'two', name: 'Второй'),
        WorkspaceModel(id: 'three', name: 'Третий'),
      ];
      final storage = _DelayedSelectionStorage();
      final repository = _FakeWorkspaceRepository(workspaces);
      final cubit = WorkspaceCubit(
        repository: repository,
        selectionStorage: storage,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final first = cubit.select(workspaces[1]);
      await storage.writing.future;
      final refreshing = cubit.load(force: true);
      await Future<void>.delayed(Duration.zero);
      final last = cubit.select(workspaces.last);
      storage.release.complete();
      await Future.wait([first, refreshing, last]);
      expect((cubit.state as WorkspaceLoaded).selected?.id, 'three');
      expect(await storage.read(), 'three');
    },
  );

  for (final superseded in [false, true]) {
    test(
      'failed selection preserves the correct workspace (superseded: $superseded)',
      () async {
        const workspaces = [
          WorkspaceModel(id: 'one', name: 'Первый'),
          WorkspaceModel(id: 'two', name: 'Второй'),
        ];
        final storage = _DelayedSelectionStorage()..failures.add('two');
        final cubit = WorkspaceCubit(
          repository: _FakeWorkspaceRepository(workspaces),
          selectionStorage: storage,
        );
        addTearDown(cubit.close);
        await cubit.load();
        final first = cubit.select(workspaces.last);
        await storage.writing.future;
        final last = superseded
            ? cubit.select(workspaces.first)
            : Future<void>.value();
        storage.release.complete();
        await Future.wait([first, last]);
        final state = cubit.state as WorkspaceLoaded;
        expect(state.selected?.id, 'one');
        expect(await storage.read(), 'one');
        expect(state.refreshError, superseded ? isNull : isNotNull);
        storage.failures.clear();
        await cubit.select(workspaces.last);
        expect((cubit.state as WorkspaceLoaded).selected?.id, 'two');
        expect(await storage.read(), 'two');
      },
    );
  }

  test('workspace creation respects a newer explicit selection', () async {
    const workspaces = [
      WorkspaceModel(id: 'one', name: 'Первый'),
      WorkspaceModel(id: 'two', name: 'Второй'),
    ];
    final pending = Completer<WorkspaceModel>();
    final storage = _DelayedSelectionStorage();
    final cubit = WorkspaceCubit(
      repository: _FakeWorkspaceRepository(
        workspaces,
        pendingCreation: pending,
      ),
      selectionStorage: storage,
    );
    addTearDown(cubit.close);
    await cubit.load();
    final creating = cubit.createWorkspace('Третий', '#6D5FE0');
    final selecting = cubit.select(workspaces.last);
    await storage.writing.future;
    pending.complete(const WorkspaceModel(id: 'three', name: 'Третий'));
    expect(await creating, isTrue);
    storage.release.complete();
    await selecting;
    final state = cubit.state as WorkspaceLoaded;
    expect(state.selected?.id, 'two');
    expect(state.workspaces.map((item) => item.id), ['one', 'two', 'three']);
    expect(state.isCreating, isFalse);
    expect(await storage.read(), 'two');
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
  test(
    'refresh receives renamed workspaces and logos without clearing content or selection',
    () async {
      final repository = _FakeWorkspaceRepository([
        const WorkspaceModel(id: 'one', name: 'Основной'),
        const WorkspaceModel(id: 'two', name: 'for me'),
      ]);
      final cubit = WorkspaceCubit(
        repository: repository,
        selectionStorage: WorkspaceSelectionStorage(
          const FlutterSecureStorage(),
        ),
      );
      await cubit.load();
      await cubit.select((cubit.state as WorkspaceLoaded).workspaces.last);
      repository.workspaces = [
        const WorkspaceModel(
          id: 'one',
          name: 'Основной',
          logoUrl: 'https://cdn.example.com/new.png',
        ),
        const WorkspaceModel(id: 'two', name: 'гринпис'),
        const WorkspaceModel(id: 'three', name: 'Поддержка'),
      ];
      final pending = cubit.load(force: true);
      expect(cubit.state, isA<WorkspaceLoaded>());
      expect((cubit.state as WorkspaceLoaded).isRefreshing, isTrue);
      await pending;
      final state = cubit.state as WorkspaceLoaded;
      expect(state.workspaces.map((w) => w.name), [
        'Основной',
        'гринпис',
        'Поддержка',
      ]);
      expect(state.selected?.id, 'two');
      expect(state.selected?.name, 'гринпис');
      expect(state.workspaces.first.logoUrl, contains('new.png'));
      expect(state.isRefreshing, isFalse);
      await cubit.close();
    },
  );

  test(
    'overlapping refreshes share request and keep a selection changed while loading',
    () async {
      final repository = _FakeWorkspaceRepository([
        const WorkspaceModel(id: 'one', name: 'Первый'),
        const WorkspaceModel(id: 'two', name: 'Второй'),
      ]);
      final storage = WorkspaceSelectionStorage(const FlutterSecureStorage());
      final cubit = WorkspaceCubit(
        repository: repository,
        selectionStorage: storage,
      );
      await cubit.load();
      final pending = Completer<List<WorkspaceModel>>();
      repository.pendingLoad = pending;
      final first = cubit.load(force: true);
      final second = cubit.load(force: true);
      expect(repository.loadCalls, 2);
      await cubit.select(repository.workspaces.last);
      pending.complete(repository.workspaces);
      await Future.wait([first, second]);
      expect((cubit.state as WorkspaceLoaded).selected?.id, 'two');
      expect(await storage.read(), 'two');
      await cubit.close();
    },
  );

  test(
    'failed refresh retains data; removal on server clears stale selection',
    () async {
      final repository = _FakeWorkspaceRepository([
        const WorkspaceModel(id: 'one', name: 'Первый'),
      ]);
      final storage = WorkspaceSelectionStorage(const FlutterSecureStorage());
      final cubit = WorkspaceCubit(
        repository: repository,
        selectionStorage: storage,
      );
      await cubit.load();
      repository.loadError = const WorkspaceException('Нет сети');
      await cubit.load(force: true);
      expect((cubit.state as WorkspaceLoaded).workspaces, hasLength(1));
      expect((cubit.state as WorkspaceLoaded).refreshError, 'Нет сети');
      repository.loadError = null;
      repository.workspaces = [];
      await cubit.load(force: true);
      expect((cubit.state as WorkspaceLoaded).selected, isNull);
      expect((cubit.state as WorkspaceLoaded).workspaces, isEmpty);
      expect(await storage.read(), isNull);
      await cubit.close();
    },
  );

  test(
    'archived list uses the server and refreshes independently from active workspaces',
    () async {
      final repository = _FakeWorkspaceRepository([
        const WorkspaceModel(id: 'one', name: 'Активный'),
      ]);
      repository.archived = [
        const WorkspaceModel(id: 'archived', name: 'Архивный'),
      ];
      final cubit = WorkspaceCubit(
        repository: repository,
        selectionStorage: WorkspaceSelectionStorage(
          const FlutterSecureStorage(),
        ),
      );
      await cubit.load();
      await cubit.loadArchived();
      expect(
        (cubit.state as WorkspaceLoaded).archivedWorkspaces.single.name,
        'Архивный',
      );
      expect(
        (cubit.state as WorkspaceLoaded).workspaces.single.name,
        'Активный',
      );
      repository.archived = [];
      await cubit.load(force: true);
      expect((cubit.state as WorkspaceLoaded).archivedWorkspaces, isEmpty);
      await cubit.close();
    },
  );
}

class _FakeWorkspaceRepository implements WorkspaceRepository {
  @override
  Future<List<WorkspaceModel>> getArchivedWorkspaces() async => archived;

  _FakeWorkspaceRepository(
    this.workspaces, {
    this.createdWorkspace,
    this.pendingCreation,
    this.creationError,
  });

  List<WorkspaceModel> workspaces;
  List<WorkspaceModel> archived = [];
  Completer<List<WorkspaceModel>>? pendingLoad;
  WorkspaceException? loadError;
  int loadCalls = 0;
  final WorkspaceModel? createdWorkspace;
  final Completer<WorkspaceModel>? pendingCreation;
  final WorkspaceException? creationError;
  int createCalls = 0;
  CreateWorkspaceRequest? lastRequest;

  @override
  Future<List<WorkspaceModel>> getWorkspaces() async {
    loadCalls++;
    if (loadError != null) throw loadError!;
    if (pendingLoad != null) return pendingLoad!.future;
    return workspaces;
  }

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

class _FailingScopeStorage extends WorkspaceSelectionStorage {
  _FailingScopeStorage() : super(const FlutterSecureStorage());
  final writing = Completer<void>();
  final release = Completer<void>();
  bool failNextScope = false;

  @override
  Future<void> saveScope(Iterable<String> ids) async {
    if (failNextScope) {
      failNextScope = false;
      writing.complete();
      await release.future;
      throw StateError('Scope storage unavailable');
    }
    await super.saveScope(ids);
  }
}

class _DelayedSelectionStorage extends WorkspaceSelectionStorage {
  _DelayedSelectionStorage() : super(const FlutterSecureStorage());
  final writing = Completer<void>();
  final release = Completer<void>();
  String? selected;
  final failures = <String>{};

  @override
  Future<String?> read() async => selected;

  @override
  Future<void> save(String workspaceId) async {
    if (workspaceId == 'two' && !writing.isCompleted) {
      writing.complete();
      await release.future;
    }
    if (failures.contains(workspaceId)) throw StateError('Storage unavailable');
    selected = workspaceId;
  }

  @override
  Future<void> clear() async => selected = null;
}
