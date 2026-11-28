import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/call_media.dart';
import '../../domain/call_protocol_repository.dart';
import '../../domain/call_repository.dart';
import '../../domain/entities/call_room.dart';

class CallProtocolState extends Equatable {
  const CallProtocolState({
    this.room,
    this.entries = const [],
    this.access = const {},
    this.versions = const [],
    this.document,
    this.total = 0,
    this.busy = false,
    this.ended = false,
    this.error,
  });
  final CallRoom? room;
  final List<CallProtocolEntry> entries;
  final Map<String, dynamic> access;
  final List<Map<String, dynamic>> versions;
  final Map<String, dynamic>? document;
  final int total;
  final bool busy, ended;
  final String? error;
  bool get canGenerate => access['canGenerate'] == true;
  bool get canManage => !ended && access['canManage'] == true;
  CallProtocolState copyWith({
    List<CallProtocolEntry>? entries,
    Map<String, dynamic>? access,
    List<Map<String, dynamic>>? versions,
    Map<String, dynamic>? document,
    int? total,
    bool? busy,
    bool? ended,
    String? error,
    bool clearDocument = false,
  }) => CallProtocolState(
    room: room,
    entries: entries ?? this.entries,
    access: access ?? this.access,
    versions: versions ?? this.versions,
    document: clearDocument ? null : document ?? this.document,
    total: total ?? this.total,
    busy: busy ?? this.busy,
    ended: ended ?? this.ended,
    error: error,
  );
  @override
  List<Object?> get props => [
    room,
    entries,
    access,
    versions,
    document,
    total,
    busy,
    ended,
    error,
  ];
}

class CallProtocolCubit extends Cubit<CallProtocolState> {
  CallProtocolCubit(this.repository, this.media)
    : super(const CallProtocolState()) {
    _subscription = media.protocolEvents.listen(_receive);
  }
  final CallProtocolRepository repository;
  final CallMedia media;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  DateTime? _startedAt, _endedAt;
  final Map<String, Map<String, dynamic>> _participants = {};
  String _localIdentity = '';
  int _generation = 0, _sequence = 0;
  Timer? _accessTimer;
  bool _refreshing = false;
  String _error(Object e) => e is CallException
      ? e.message
      : 'Не удалось загрузить или сохранить протокол. Попробуйте ещё раз.';
  bool _current(int generation) => !isClosed && generation == _generation;

  void begin(CallRoom room, DateTime startedAt) {
    clear();
    _startedAt = startedAt;
    _localIdentity = media.localIdentity;
    emit(CallProtocolState(room: room));
    _rememberParticipants();
    unawaited(refresh());
    _accessTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(refreshAccess()),
    );
  }

  void loadArchive(CallRoom room) {
    clear();
    emit(CallProtocolState(room: room, ended: true));
    unawaited(refresh());
  }

  void _rememberParticipants() {
    for (final entry in media.protocolParticipants.entries) {
      _participants[entry.key] = {
        ...?_participants[entry.key],
        'name': entry.value,
      };
    }
  }

  void end() {
    if (state.room == null || state.ended) return;
    _rememberParticipants();
    _endedAt = DateTime.now();
    _accessTimer?.cancel();
    emit(state.copyWith(ended: true));
  }

  void clear() {
    ++_generation;
    _accessTimer?.cancel();
    _participants.clear();
    _startedAt = _endedAt = null;
    _refreshing = false;
    emit(const CallProtocolState());
  }

  Future<void> refreshAccess() async {
    final room = state.room;
    if (room == null || _refreshing) return;
    final generation = _generation;
    _refreshing = true;
    try {
      final access = await repository.access(room);
      if (_current(generation)) {
        final participants = access['participants'];
        if (participants is List) {
          for (final item in participants.whereType<Map>()) {
            if (item['id'] is String) {
              _participants[item['id'] as String] = Map<String, dynamic>.from(
                item,
              );
            }
          }
        }
        emit(state.copyWith(access: access));
      }
    } catch (e) {
      if (_current(generation)) emit(state.copyWith(error: _error(e)));
    } finally {
      if (_current(generation)) _refreshing = false;
    }
  }

  Future<void> refresh({bool more = false}) async {
    if (state.room == null || state.busy) return;
    final room = state.room!;
    final generation = _generation;
    emit(state.copyWith(busy: true));
    await refreshAccess();
    if (!_current(generation)) return;
    final accessError = state.error;
    try {
      final page = await repository.versions(
        room,
        more ? state.versions.length : 0,
      );
      if (!_current(generation)) return;
      final items = page['items'];
      final versions = items is List
          ? items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      emit(
        state.copyWith(
          versions: more ? [...state.versions, ...versions] : versions,
          total: page['total'] is int ? page['total'] as int : versions.length,
          busy: false,
          error: accessError,
        ),
      );
    } catch (e) {
      if (_current(generation)) {
        emit(state.copyWith(busy: false, error: _error(e)));
      }
    }
  }

  void _receive(Map<String, dynamic> data) {
    if (state.room == null || state.ended) return;
    final type = data['type'];
    if (type == 'summary-access-changed') {
      unawaited(refreshAccess());
      return;
    }
    if (type == 'key-decision') {
      emit(
        state.copyWith(
          entries: [
            for (final entry in state.entries)
              if (entry.id == data['entryId'])
                entry.copyWith(isKeyDecision: data['value'] == true)
              else
                entry,
          ],
        ),
      );
      return;
    }
    if (type != 'speech' && type != 'chat') return;
    final entry = CallProtocolEntry.fromJson({
      ...data,
      'kind': type,
      if (type == 'chat' && data['id'] is! String)
        'id':
            'web-chat-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
    });
    if (entry.id.isEmpty ||
        entry.text.trim().isEmpty ||
        entry.text.length > 16000 ||
        state.entries.any((e) => e.id == entry.id) ||
        state.entries.length >= 10000) {
      return;
    }
    _rememberParticipants();
    emit(state.copyWith(entries: [...state.entries, entry]));
  }

  String _duration(DateTime end) {
    final seconds = end
        .difference(_startedAt ?? end)
        .inSeconds
        .clamp(0, 359999);
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<bool> addNote(String text) async {
    text = text.trim();
    if (text.isEmpty ||
        text.length > 16000 ||
        state.room == null ||
        state.busy) {
      return false;
    }
    final generation = _generation;
    final entry = CallProtocolEntry(
      id: 'mobile-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      userId: _localIdentity,
      text: text,
      timestamp: _duration(_endedAt ?? DateTime.now()),
    );
    try {
      if (!state.ended) {
        await media.publishProtocol({'type': 'chat', ...entry.toJson()});
      }
      if (!_current(generation)) return false;
      emit(
        state.copyWith(entries: [...state.entries, entry], clearDocument: true),
      );
      return true;
    } catch (e) {
      if (_current(generation)) emit(state.copyWith(error: _error(e)));
      return false;
    }
  }

  Future<void> toggleDecision(CallProtocolEntry entry) async {
    if (state.busy) return;
    final generation = _generation;
    try {
      if (!state.ended) {
        await media.publishProtocol({
          'type': 'key-decision',
          'entryId': entry.id,
          'value': !entry.isKeyDecision,
        });
      }
      if (!_current(generation)) return;
      emit(
        state.copyWith(
          entries: [
            for (final e in state.entries)
              if (e.id == entry.id)
                e.copyWith(isKeyDecision: !e.isKeyDecision)
              else
                e,
          ],
        ),
      );
    } catch (e) {
      if (_current(generation)) emit(state.copyWith(error: _error(e)));
    }
  }

  Future<void> grant(String userId, bool enabled) async {
    if (!state.canManage || state.busy) return;
    final generation = _generation;
    emit(state.copyWith(busy: true));
    try {
      final access = await repository.grant(state.room!, userId, enabled);
      if (!_current(generation)) return;
      emit(state.copyWith(access: access, busy: false));
      unawaited(
        media
            .publishProtocol({'type': 'summary-access-changed'})
            .catchError((Object _) {}),
      );
    } catch (e) {
      if (_current(generation)) {
        emit(state.copyWith(busy: false, error: _error(e)));
      }
    }
  }

  Future<void> save() async {
    if (!state.canGenerate ||
        state.busy ||
        state.entries.isEmpty ||
        state.room == null) {
      return;
    }
    final generation = _generation;
    final room = state.room!;
    final now = DateTime.now();
    _rememberParticipants();
    final entries = state.entries.map((e) => e.toJson()).toList();
    final suffix = room.id.length > 8
        ? room.id.substring(room.id.length - 8)
        : room.id;
    final content = <String, dynamic>{
      'documentNumber': '${now.year}-${suffix.toUpperCase()}',
      'duration': _duration(_endedAt ?? now),
      'date': _startedAt?.toIso8601String(),
      'startedAt': _startedAt?.toIso8601String(),
      'generatedAt': now.toIso8601String(),
      'participantIds': _participants.keys.toList(),
      'participantDetails': Map.of(_participants),
      'keyDecisions': entries.where((e) => e['isKeyDecision'] == true).toList(),
      'totalMessages': entries.length,
      'speechCount': entries.where((e) => e['kind'] == 'speech').length,
      'chatCount': entries.where((e) => e['kind'] == 'chat').length,
      'allEntries': entries,
    };
    emit(state.copyWith(busy: true));
    try {
      final saved = await repository.save(room, content);
      if (!_current(generation)) return;
      final document = saved['content'];
      emit(
        state.copyWith(
          busy: false,
          document: document is Map
              ? Map<String, dynamic>.from(document)
              : content,
        ),
      );
      await refresh();
    } catch (e) {
      if (_current(generation)) {
        emit(state.copyWith(busy: false, error: _error(e)));
      }
    }
  }

  Future<void> open(String id) async {
    if (state.room == null || state.busy) return;
    final generation = _generation;
    emit(state.copyWith(busy: true));
    try {
      final saved = await repository.version(state.room!, id);
      if (!_current(generation)) return;
      final content = saved['content'];
      emit(
        state.copyWith(
          busy: false,
          document: content is Map
              ? Map<String, dynamic>.from(content)
              : const {},
        ),
      );
    } catch (e) {
      if (_current(generation)) {
        emit(state.copyWith(busy: false, error: _error(e)));
      }
    }
  }

  void showDraft() => emit(state.copyWith(clearDocument: true));
  @override
  Future<void> close() async {
    ++_generation;
    _accessTimer?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
