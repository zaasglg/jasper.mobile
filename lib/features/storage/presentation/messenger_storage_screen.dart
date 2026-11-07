import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/storage/workspace_selection_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/data/models/chat_conversation_model.dart';
import '../../chat/presentation/cubit/chat_cubit.dart';
import '../data/storage_models.dart';

/// The web storage belongs to a thread; choose that thread before opening files.
class MessengerStorageScreen extends StatefulWidget {
  const MessengerStorageScreen({super.key});
  @override
  State<MessengerStorageScreen> createState() => _MessengerStorageScreenState();
}

class _MessengerStorageScreenState extends State<MessengerStorageScreen> {
  String _query = '';
  bool _opening = false;
  Future<void> _open(ChatConversationModel chat) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final workspaceId = await sl<WorkspaceSelectionStorage>().read();
      if (!mounted) return;
      if (workspaceId == null || workspaceId.isEmpty) {
        throw StateError('workspace');
      }
      final id = await context.push<String>(
        '/storage',
        extra: StorageScope(
          source: StorageSource.chat,
          id: chat.threadId,
          workspaceId: workspaceId,
          title: chat.title,
        ),
      );
      if (id != null && mounted) {
        final uri = Uri(
          path: '/messenger/${Uri.encodeComponent(chat.id)}',
          queryParameters: {'messageId': id},
        );
        await context.push(uri.toString(), extra: chat);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть кладовку. Повторите попытку.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Кладовка мессенджера'),
      leading: IconButton(
        tooltip: 'Назад',
        onPressed: context.pop,
        icon: const Icon(LucideIcons.arrowLeft, size: 18),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              'Выберите переписку или канал',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Поиск переписки',
                prefixIcon: Icon(LucideIcons.search, size: 16),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          if (_opening) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) {
                if (state is ChatLoading) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (state is ChatFailure) {
                  return Center(
                    child: TextButton(
                      onPressed: context.read<ChatCubit>().load,
                      child: const Text('Повторить загрузку'),
                    ),
                  );
                }
                final items = (state as ChatLoaded).conversations
                    .where((e) => e.title.toLowerCase().contains(_query))
                    .toList();
                if (items.isEmpty) {
                  return const Center(child: Text('Переписки не найдены'));
                }
                return RefreshIndicator(
                  onRefresh: context.read<ChatCubit>().load,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      for (final isChannel in [true, false]) ...[
                        if (items.any((e) => e.isChannel == isChannel))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                            child: Text(
                              isChannel ? 'КАНАЛЫ' : 'ЛИЧНЫЕ СООБЩЕНИЯ',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .7,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        for (final chat in items.where(
                          (e) => e.isChannel == isChannel,
                        ))
                          ListTile(
                            enabled: !_opening,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isChannel
                                    ? LucideIcons.hash
                                    : LucideIcons.messageCircle,
                                color: AppColors.accent,
                                size: 16,
                              ),
                            ),
                            title: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'Файлы, ссылки и резюме встреч',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            trailing: const Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: AppColors.muted,
                            ),
                            onTap: () => _open(chat),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
