import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/service_locator.dart';
import '../data/storage_collector.dart';
import '../data/storage_models.dart';
import '../domain/storage_repository.dart';
import 'storage_cubit.dart';

class StorageSummaryScreen extends StatefulWidget {
  const StorageSummaryScreen({
    required this.scope,
    required this.summary,
    super.key,
  });
  final StorageScope scope;
  final StorageSummary summary;
  @override
  State<StorageSummaryScreen> createState() => _StorageSummaryScreenState();
}

class _StorageSummaryScreenState extends State<StorageSummaryScreen> {
  late Future<StorageSummary> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = sl<StorageRepository>().summary(widget.scope, widget.summary);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Резюме встречи')),
    body: FutureBuilder<StorageSummary>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(StorageCubit.errorText(snapshot.error!)),
                TextButton(
                  onPressed: () => setState(_load),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final summary = snapshot.data!;
        final content = summary.content;
        final people = StorageCollector.object(content['participantDetails']);
        final decisions = (content['keyDecisions'] as List? ?? [])
            .whereType<Map>();
        final entries = (content['allEntries'] as List? ?? []).whereType<Map>();
        Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        );
        Widget entry(Map raw) {
          final person = StorageCollector.object(people[raw['userId']]);
          final task = StorageCollector.object(raw['createdTask']);
          final file = StorageCollector.object(raw['file']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person['name']?.toString() ?? raw['userId']?.toString() ?? '',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(raw['text']?.toString() ?? ''),
                if (task['id'] != null)
                  TextButton.icon(
                    onPressed: () => context.push(
                      '/tasks/${Uri.encodeComponent(task['id'].toString())}',
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(task['title']?.toString() ?? 'Открыть задачу'),
                  ),
                if (file['dataUrl'] != null)
                  TextButton.icon(
                    onPressed: () => context.push(
                      '/storage-file',
                      extra: (
                        widget.scope,
                        StorageItem(
                          id: raw['id']?.toString() ?? '',
                          name: file['name']?.toString() ?? 'Файл',
                          kind: StorageCollector.classify(
                            file['name']?.toString() ?? '',
                            file['mimeType']?.toString() ?? '',
                          ),
                          date: summary.date,
                          dataUrl: file['dataUrl'].toString(),
                          mimeType: file['mimeType']?.toString() ?? '',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: Text(file['name']?.toString() ?? 'Файл'),
                  ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              summary.number.isEmpty ? 'Встреча' : summary.number,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.date.toLocal().toString().substring(0, 16)} · ${summary.authorName}',
            ),
            if (content['duration'] != null)
              Text('Длительность: ${content['duration']}'),
            heading('Участники'),
            for (final person in people.values)
              Text(StorageCollector.object(person)['name']?.toString() ?? ''),
            if (people.isEmpty) const Text('Участники не указаны'),
            heading('Ключевые решения'),
            if (decisions.isEmpty) const Text('Нет отмеченных решений'),
            ...decisions.map(entry),
            heading('Стенограмма'),
            if (entries.isEmpty) const Text('Нет записей'),
            ...entries.map(entry),
          ],
        );
      },
    ),
  );
}
