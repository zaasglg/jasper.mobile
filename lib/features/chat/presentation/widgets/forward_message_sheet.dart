import 'package:jospar/core/localization/app_translations.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_form_surface.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/models/chat_conversation_model.dart';
import '../../data/models/chat_message_model.dart';
import '../cubit/conversation_cubit.dart';
import '../messenger_list_strings.dart';
import 'channel_avatar.dart';

class ForwardMessageSheet extends StatefulWidget {
  const ForwardMessageSheet({
    super.key,
    required this.cubit,
    required this.message,
  });
  final ConversationCubit cubit;
  final ChatMessageModel message;

  @override
  State<ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends State<ForwardMessageSheet> {
  late Future<List<ChatConversationModel>> _targets;
  String _query = '';
  String? _error, _sending;

  @override
  void initState() {
    super.initState();
    _targets = widget.cubit.forwardTargets();
  }

  Future<void> _send(ChatConversationModel target) async {
    if (_sending != null) return;
    setState(() {
      _sending = target.id;
      _error = null;
    });
    final success = await widget.cubit.forward(widget.message, target);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _sending = null;
        _error =
            widget.cubit.state.error ??
            (MessengerListStrings.of(context).kk
                ? 'Хабарламаны жіберу мүмкін болмады'
                : 'Не удалось переслать сообщение');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = MessengerListStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _sending == null,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: .88,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, 'Переслать сообщение'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, 'Отмена'),
                        onPressed: _sending == null
                            ? () => Navigator.pop(context)
                            : null,
                        icon: const Icon(Icons.close, size: 22),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppFormSurface(
                    child: TextField(
                      enabled: _sending == null,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: tr(context, 'Найти чат'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<ChatConversationModel>>(
                    future: _targets,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: TextButton(
                            onPressed: () => setState(
                              () => _targets = widget.cubit.forwardTargets(),
                            ),
                            child: Text(
                              tr(context, 'Повторить загрузку чатов'),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final all = snapshot.data!;
                      final byId = {for (final item in all) item.id: item};
                      final query = _query.trim().toLowerCase();
                      bool matches(ChatConversationModel item) =>
                          item.title.toLowerCase().contains(query);
                      final visible = all
                          .where(matches)
                          .map((e) => e.id)
                          .toSet();
                      // Include ancestors so a search result retains its channel context.
                      for (final item in all.where(matches)) {
                        var parent = item.parentId;
                        final visited = <String>{item.id};
                        while (parent != null && visited.add(parent)) {
                          visible.add(parent);
                          parent = byId[parent]?.parentId;
                        }
                      }
                      final channels = all.where((e) => e.isChannel).toList();
                      final people = all
                          .where((e) => !e.isChannel && visible.contains(e.id))
                          .toList();
                      final ordered =
                          <({ChatConversationModel item, int depth})>[];
                      final visited = <String>{};
                      void visit(ChatConversationModel item, int depth) {
                        if (!visited.add(item.id)) return;
                        if (visible.contains(item.id)) {
                          ordered.add((item: item, depth: depth));
                        }
                        for (final child in channels.where(
                          (e) => e.parentId == item.id,
                        )) {
                          visit(child, depth + 1);
                        }
                      }

                      for (final item in channels.where(
                        (e) => !byId.containsKey(e.parentId),
                      )) {
                        visit(item, 0);
                      }
                      for (final item in channels) {
                        visit(item, 0);
                      }
                      if (ordered.isEmpty && people.isEmpty) {
                        return Center(
                          child: Text(tr(context, 'Чаты не найдены')),
                        );
                      }
                      Widget heading(String text) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      );
                      return ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          if (ordered.isNotEmpty)
                            heading(strings.folder('channels')),
                          for (final entry in ordered)
                            _targetTile(entry.item, entry.depth, byId, strings),
                          if (people.isNotEmpty)
                            heading(strings.personalMessages),
                          for (final person in people)
                            _targetTile(person, 0, byId, strings),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      tr(context, _error!),
                      style: TextStyle(color: AppColors.of(context).error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _targetTile(
    ChatConversationModel target,
    int depth,
    Map<String, ChatConversationModel> byId,
    MessengerListStrings strings,
  ) {
    final child = target.isChannel && target.parentId != null;
    final parent = byId[target.parentId];
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: depth.clamp(0, 3) * 24.0),
      child: ListTile(
        key: ValueKey('forward-target-${target.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: target.isChannel
            ? ChannelAvatar(
                channelId: target.id,
                imageUrl: target.imageUrl,
                size: 44,
              )
            : UserAvatar(
                size: 44,
                userId: target.id,
                name: target.title,
                avatarUrl: target.avatarUrl,
              ),
        title: Text(
          target.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          child
              ? '${strings.subchannel}${parent == null ? '' : ' · ${parent.title}'}'
              : target.isChannel
              ? strings.channel
              : strings.personal,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        trailing: _sending == target.id
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : child
            ? Icon(
                Icons.subdirectory_arrow_right,
                size: 18,
                color: colors.onSurfaceVariant,
              )
            : null,
        enabled: _sending == null,
        onTap: () => _send(target),
      ),
    );
  }
}
