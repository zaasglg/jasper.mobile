import '../../domain/entities/call_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/app_translations.dart';
import '../../domain/call_protocol_repository.dart';
import '../call_cubit.dart';
import 'call_protocol_cubit.dart';

class CallProtocolScreen extends StatefulWidget {
  const CallProtocolScreen({super.key, this.cubit, this.archiveRoom});
  final CallProtocolCubit? cubit;
  final CallRoom? archiveRoom;
  @override
  State<CallProtocolScreen> createState() => _CallProtocolScreenState();
}

class _CallProtocolScreenState extends State<CallProtocolScreen> {
  CallProtocolCubit? _archive;
  @override
  void initState() {
    super.initState();
    if (widget.archiveRoom case final room?
        when room.id != sl<CallCubit>().protocol?.state.room?.id) {
      _archive = CallProtocolCubit(
        sl<CallProtocolRepository>(),
        sl<CallCubit>().media,
      )..loadArchive(room);
    }
  }

  final _note = TextEditingController();
  CallProtocolCubit? get cubit =>
      widget.cubit ?? _archive ?? sl<CallCubit>().protocol;
  @override
  void dispose() {
    _note.dispose();
    _archive?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = cubit;
    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Протокол звонка'))),
      );
    }
    return BlocBuilder<CallProtocolCubit, CallProtocolState>(
      bloc: current,
      builder: (context, state) {
        final colors = Theme.of(context).colorScheme;
        final document = state.document;
        final raw = document?['allEntries'];
        final entries = document == null
            ? state.entries
            : raw is List
            ? raw
                  .whereType<Map>()
                  .map(
                    (e) => CallProtocolEntry.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList()
            : <CallProtocolEntry>[];
        final details = document?['participantDetails'];
        final participants = state.access['participants'];
        String name(String id) {
          if (details is Map &&
              details[id] is Map &&
              details[id]['name'] is String) {
            return details[id]['name'] as String;
          }
          if (participants is List) {
            for (final p in participants.whereType<Map>()) {
              if (p['id'] == id && p['name'] is String) {
                return p['name'] as String;
              }
            }
          }
          return tr(context, 'Участник');
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'Протокол звонка')),
            actions: [
              IconButton(
                tooltip: tr(context, 'Обновить'),
                onPressed: state.busy ? null : current.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: state.room == null
                ? Center(child: Text(tr(context, 'Нет активного протокола')))
                : Column(
                    children: [
                      if (state.busy) const LinearProgressIndicator(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Text(
                              state.room!.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(
                                context,
                                state.ended
                                    ? 'Звонок завершён'
                                    : 'Заметки звонка',
                              ),
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              tr(
                                context,
                                'В протокол входят заметки и полученная расшифровка веб-участников. Речь телефона автоматически не записывается.',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (state.error != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  tr(context, state.error!),
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            if (document != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                '${document['documentNumber'] ?? ''} · ${document['duration'] ?? ''}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              TextButton(
                                onPressed: current.showDraft,
                                child: Text(tr(context, 'К заметкам звонка')),
                              ),
                            ],
                            if (entries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                ),
                                child: Text(
                                  tr(
                                    context,
                                    _archive != null
                                        ? 'Сохранённых протоколов пока нет.'
                                        : 'Пока нет записей. Добавьте заметку или решение.',
                                  ),
                                ),
                              ),
                            for (final entry in entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: entry.isKeyDecision
                                        ? colors.primaryContainer
                                        : colors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${name(entry.userId)} · ${entry.timestamp}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      SelectableText(entry.text),
                                      if (document == null && _archive == null)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: state.busy
                                                ? null
                                                : () => current.toggleDecision(
                                                    entry,
                                                  ),
                                            icon: Icon(
                                              entry.isKeyDecision
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              size: 18,
                                            ),
                                            label: Text(
                                              tr(
                                                context,
                                                entry.isKeyDecision
                                                    ? 'Ключевое решение'
                                                    : 'Отметить решение',
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            if (document == null && _archive == null) ...[
                              TextField(
                                controller: _note,
                                minLines: 2,
                                maxLines: 5,
                                maxLength: 16000,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'Заметка или решение'),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: state.busy
                                      ? null
                                      : () async {
                                          final text = _note.text;
                                          if (await current.addNote(text) &&
                                              mounted &&
                                              _note.text == text) {
                                            _note.clear();
                                          }
                                        },
                                  icon: const Icon(Icons.add),
                                  label: Text(tr(context, 'Добавить заметку')),
                                ),
                              ),
                              if (state.canGenerate)
                                FilledButton.icon(
                                  onPressed: state.busy || state.entries.isEmpty
                                      ? null
                                      : current.save,
                                  icon: const Icon(Icons.description_outlined),
                                  label: Text(
                                    tr(context, 'Сохранить протокол'),
                                  ),
                                )
                              else
                                Text(
                                  tr(
                                    context,
                                    'Создание протокола доступно с разрешения администратора.',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                            if (state.canManage && participants is List) ...[
                              const SizedBox(height: 24),
                              Text(
                                tr(context, 'Кто может создавать протокол'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (final p in participants.whereType<Map>())
                                if (p['id'] is String)
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      p['name'] is String
                                          ? p['name'] as String
                                          : tr(context, 'Участник'),
                                    ),
                                    value:
                                        state.access['grantedUserIds']
                                            is List &&
                                        (state.access['grantedUserIds'] as List)
                                            .contains(p['id']),
                                    onChanged: state.busy
                                        ? null
                                        : (value) => current.grant(
                                            p['id'] as String,
                                            value,
                                          ),
                                  ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              tr(context, 'Сохранённые протоколы'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            for (final version in state.versions)
                              if (version['id'] is String)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.description_outlined,
                                  ),
                                  title: Text(
                                    '${version['documentNumber'] ?? ''}',
                                  ),
                                  subtitle: Text(
                                    '${version['duration'] ?? ''} · ${version['createdAt'] ?? ''}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: state.busy
                                      ? null
                                      : () => current.open(
                                          version['id'] as String,
                                        ),
                                ),
                            if (state.versions.length < state.total)
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => current.refresh(more: true),
                                child: Text(tr(context, 'Показать ещё')),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
