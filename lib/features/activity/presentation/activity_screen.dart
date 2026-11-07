import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_icon_sizes.dart';
import '../../chat/domain/repositories/chat_repository.dart';
import '../data/activity_repository.dart';

class ActivityState extends Equatable {
  const ActivityState({this.items = const [], this.loading = true, this.error});
  final List<ActivityEntry> items;
  final bool loading;
  final String? error;
  @override
  List<Object?> get props => [items, loading, error];
}

class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit(this.repository, this.kind) : super(const ActivityState());
  final ActivityRepository repository;
  final ActivityKind kind;
  Future<void> load() async {
    if (isClosed) return;
    emit(ActivityState(items: state.items));
    try {
      final items = await repository.load(kind);
      if (!isClosed) emit(ActivityState(items: items, loading: false));
    } catch (_) {
      if (!isClosed) {
        emit(
          ActivityState(
            items: state.items,
            loading: false,
            error: 'Не удалось загрузить данные. Повторите попытку.',
          ),
        );
      }
    }
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({required this.kind, super.key});
  final ActivityKind kind;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ActivityCubit(sl<ActivityRepository>(), kind)..load(),
    child: _ActivityBody(kind: kind),
  );
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody({required this.kind});
  final ActivityKind kind;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ActivityCubit, ActivityState>(
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: Text(switch (kind) {
              ActivityKind.notifications => 'Уведомления',
              ActivityKind.mentions => 'Упоминания и реакции',
              ActivityKind.discussions => 'Обсуждения',
              ActivityKind.saved => 'Сохранённое',
            }),
          ),
          body: RefreshIndicator(
            onRefresh: context.read<ActivityCubit>().load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (state.loading) const LinearProgressIndicator(minHeight: 2),
                if (state.error != null)
                  TextButton(
                    onPressed: context.read<ActivityCubit>().load,
                    child: Text(state.error!),
                  ),
                if (!state.loading &&
                    state.error == null &&
                    state.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Center(child: Text('Пока ничего нет')),
                  ),
                for (final entry in state.items)
                  ListTile(
                    leading: Icon(
                      kind == ActivityKind.saved
                          ? LucideIcons.bookmark
                          : LucideIcons.messageSquare,
                      size: AppIconSizes.standard,
                    ),
                    title: Text(
                      entry.title.isEmpty
                          ? (entry.taskId == null ? 'Сообщение' : 'Задача')
                          : entry.title,
                    ),
                    subtitle: Text(
                      entry.text.isEmpty ? 'Вложение' : entry.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _open(context, entry),
                  ),
              ],
            ),
          ),
        ),
      );
  Future<void> _open(BuildContext context, ActivityEntry entry) async {
    if (entry.taskId != null) {
      await context.push('/tasks/${entry.taskId}');
      return;
    }
    if (entry.threadId == null) return;
    try {
      final chats = await sl<ChatRepository>().getConversations();
      final matches = chats.where(
        (chat) => chat.threadId == entry.threadId || chat.id == entry.threadId,
      );
      if (!context.mounted) return;
      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Обсуждение больше недоступно.')),
        );
        return;
      }
      final chat = matches.first;
      await context.push(
        '/messenger/${Uri.encodeComponent(chat.id)}',
        extra: chat,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть обсуждение.')),
        );
      }
    }
  }
}
