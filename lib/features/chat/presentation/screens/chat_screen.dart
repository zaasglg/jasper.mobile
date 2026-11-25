import 'package:jospar/core/localization/app_translations.dart';
import 'dart:math' as math;
import '../../../../core/widgets/app_action_menu.dart';
import '../messenger_list_strings.dart';
import '../widgets/channel_avatar.dart';
import '../../domain/repositories/channel_image_repository.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../widgets/conversation_menu.dart';
import '../widgets/messenger_refresh_lifecycle.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/app_form_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/models/chat_conversation_model.dart';
import '../../data/models/chat_message_model.dart';
import '../cubit/chat_cubit.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar.dart';

enum _ChatFolder { all, channels, people }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with MessengerRefreshLifecycle<ChatScreen> {
  late ChatCubit _refreshCubit;
  @override
  String get messengerRefreshPath => '/messenger';
  @override
  void setMessengerRefresh(bool active) => _refreshCubit.setAutoRefresh(active);
  @override
  void invalidateMessenger() => _refreshCubit.invalidate();
  @override
  void initState() {
    super.initState();
    _refreshCubit = context.read<ChatCubit>();
  }

  final _searchController = TextEditingController();
  String _query = '';
  _ChatFolder _folder = _ChatFolder.all;
  bool _channelsExpanded = true;
  final Set<String> _expandedChannels = {};
  bool _peopleExpanded = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strings = MessengerListStrings.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: const DashboardAppBar(),
      floatingActionButton: FloatingActionButton(
        key: const Key('messenger-compose'),
        tooltip: strings.newChat,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        onPressed: _compose,
        child: const Icon(LucideIcons.pencil, size: 23),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Search(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .4),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final folder in _ChatFolder.values)
                            Semantics(
                              selected: _folder == folder,
                              button: true,
                              child: InkWell(
                                key: ValueKey(
                                  'messenger-folder-${folder.name}',
                                ),
                                onTap: () => setState(() => _folder = folder),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    11,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 3,
                                        color: _folder == folder
                                            ? AppColors.accent
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    strings.folder(folder.name),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _folder == folder
                                          ? AppColors.accent
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('messenger-tools'),
                    tooltip: strings.tools,
                    onPressed: _showTools,
                    icon: Icon(
                      LucideIcons.ellipsis,
                      size: 21,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<ChatCubit, ChatState>(
                builder: (context, state) {
                  if (state is ChatLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ChatFailure) {
                    return _LoadError(
                      message: state.message,
                      onRetry: context.read<ChatCubit>().load,
                    );
                  }
                  final conversations = (state as ChatLoaded).conversations;
                  final filtered = _filtered(conversations);
                  final channelChildren = <String, int>{};
                  for (final channel in conversations.where(
                    (item) => item.isChannel && item.parentId != null,
                  )) {
                    channelChildren.update(
                      channel.parentId!,
                      (count) => count + 1,
                      ifAbsent: () => 1,
                    );
                  }
                  final channels = _orderedChannels(
                    filtered.where((item) => item.isChannel).toList(),
                  );
                  final people = filtered
                      .where(
                        (item) =>
                            !item.isChannel &&
                            (_query.isNotEmpty || item.hasThread),
                      )
                      .toList();
                  final visible = [
                    if (_folder != _ChatFolder.people) ...channels,
                    if (_folder != _ChatFolder.channels) ...people,
                  ];
                  final titles = {
                    for (final item in conversations) item.id: item.title,
                  };
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<ChatCubit>().load(silent: true),
                    child: visible.isEmpty
                        ? CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _NoResults(isSearch: _query.isNotEmpty),
                              ),
                            ],
                          )
                        : CustomScrollView(
                            key: const Key('messenger-list'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              for (final isChannel in [true, false])
                                if ((isChannel
                                        ? _folder != _ChatFolder.people
                                        : _folder != _ChatFolder.channels) &&
                                    (isChannel
                                        ? channels.isNotEmpty
                                        : people.isNotEmpty)) ...[
                                  SliverToBoxAdapter(
                                    child: _ConversationGroupHeader(
                                      key: ValueKey(
                                        'messenger-section-${isChannel ? 'channels' : 'people'}',
                                      ),
                                      title: isChannel
                                          ? strings.folder('channels')
                                          : strings.personalMessages,
                                      count: isChannel
                                          ? filtered
                                                .where((item) => item.isChannel)
                                                .length
                                          : people.length,
                                      expanded:
                                          _query.isNotEmpty ||
                                          (isChannel
                                              ? _channelsExpanded
                                              : _peopleExpanded),
                                      onToggle: () => setState(() {
                                        if (isChannel) {
                                          _channelsExpanded =
                                              !_channelsExpanded;
                                        } else {
                                          _peopleExpanded = !_peopleExpanded;
                                        }
                                      }),
                                      onAdd: () => isChannel
                                          ? _showCreateChannel(
                                              conversations
                                                  .where((e) => e.isChannel)
                                                  .toList(),
                                            )
                                          : _showPeople(
                                              conversations
                                                  .where((e) => !e.isChannel)
                                                  .toList(),
                                            ),
                                      addLabel: isChannel
                                          ? strings.addChannel
                                          : strings.addPerson,
                                    ),
                                  ),
                                  if (_query.isNotEmpty ||
                                      (isChannel
                                          ? _channelsExpanded
                                          : _peopleExpanded))
                                    SliverList.builder(
                                      itemCount: isChannel
                                          ? channels.length
                                          : people.length,
                                      itemBuilder: (context, index) {
                                        final group = isChannel
                                            ? channels
                                            : people;
                                        final item = group[index];
                                        final depth = isChannel
                                            ? _channelDepth(item, conversations)
                                            : 0;
                                        return Column(
                                          children: [
                                            _Conversation(
                                              item: item,
                                              isChannel: item.isChannel,
                                              depth: depth,
                                              hasChildren:
                                                  isChannel &&
                                                  channelChildren.containsKey(
                                                    item.id,
                                                  ),
                                              childrenExpanded:
                                                  _query.isNotEmpty ||
                                                  _expandedChannels.contains(
                                                    item.id,
                                                  ),
                                              onToggleChildren: () =>
                                                  setState(() {
                                                    if (!_expandedChannels.add(
                                                      item.id,
                                                    )) {
                                                      _expandedChannels.remove(
                                                        item.id,
                                                      );
                                                    }
                                                  }),
                                              continuesBranch:
                                                  isChannel &&
                                                  index + 1 < group.length &&
                                                  group[index + 1].parentId ==
                                                      item.parentId,
                                              parentTitle: item.parentId == null
                                                  ? null
                                                  : titles[item.parentId],
                                              onTap: () =>
                                                  _openConversation(item),
                                            ),
                                            if (index < group.length - 1 &&
                                                !(isChannel &&
                                                    group[index + 1].parentId ==
                                                        item.id))
                                              Divider(
                                                height: 1,
                                                thickness: .5,
                                                indent: 82 + depth * 36,
                                                color: colors.outlineVariant
                                                    .withValues(alpha: .4),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 88),
                              ),
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

  Future<void> _compose() async {
    final current = context.read<ChatCubit>().state;
    if (current is! ChatLoaded) return;
    final strings = MessengerListStrings.of(context);
    final action = await showAppActionMenu<String>(
      context,
      title: strings.newChat,
      groups: [
        [
          AppMenuAction(
            value: 'person',
            label: strings.addPerson,
            icon: LucideIcons.messageCircle,
          ),
          AppMenuAction(
            value: 'channel',
            label: strings.addChannel,
            icon: LucideIcons.hash,
          ),
        ],
      ],
    );
    if (!mounted) return;
    if (action == 'channel') {
      await _showCreateChannel(
        current.conversations.where((e) => e.isChannel).toList(),
      );
    } else if (action == 'person') {
      await _showPeople(
        current.conversations.where((e) => !e.isChannel).toList(),
      );
    }
  }

  Future<void> _showTools() async {
    final strings = MessengerListStrings.of(context);
    final route = await showAppActionMenu<String>(
      context,
      title: strings.tools,
      groups: [
        [
          AppMenuAction(
            value: '/activity/mentions',
            label: strings.mentions,
            icon: LucideIcons.atSign,
          ),
          AppMenuAction(
            value: '/activity/saved',
            label: strings.saved,
            icon: LucideIcons.bookmark,
          ),
          AppMenuAction(
            value: '/messenger-storage',
            label: strings.storage,
            icon: LucideIcons.archive,
          ),
        ],
      ],
    );
    if (mounted && route != null) await context.push(route);
  }

  int _channelDepth(
    ChatConversationModel item,
    List<ChatConversationModel> items,
  ) {
    final parents = {
      for (final channel in items.where((e) => e.isChannel))
        channel.id: channel.parentId,
    };
    final visited = <String>{item.id};
    var parent = item.parentId;
    var depth = 0;
    while (parent != null && depth < 2 && visited.add(parent)) {
      depth++;
      parent = parents[parent];
    }
    return depth;
  }

  List<ChatConversationModel> _filtered(List<ChatConversationModel> items) =>
      _query.isEmpty
      ? items
      : items
            .where(
              (item) => item.title.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();

  void _openConversation(ChatConversationModel item) {
    final uri = Uri(path: '/messenger/${Uri.encodeComponent(item.id)}');
    context.push(uri.toString(), extra: item);
  }

  List<ChatConversationModel> _orderedChannels(
    List<ChatConversationModel> channels,
  ) {
    final byParent = <String?, List<ChatConversationModel>>{};
    for (final channel in channels) {
      byParent.putIfAbsent(channel.parentId, () => []).add(channel);
    }
    final result = <ChatConversationModel>[];
    final visited = <String>{};
    final ids = channels.map((item) => item.id).toSet();
    void append(ChatConversationModel item, bool visible) {
      if (!visited.add(item.id)) return;
      if (visible) result.add(item);
      final showChildren =
          visible && (_query.isNotEmpty || _expandedChannels.contains(item.id));
      for (final child in byParent[item.id] ?? <ChatConversationModel>[]) {
        append(child, showChildren);
      }
    }

    for (final item in channels) {
      if (item.parentId == null || !ids.contains(item.parentId)) {
        append(item, true);
      }
    }
    // Retain accessible entries even if the server sends a cyclic hierarchy.
    for (final item in channels) {
      if (!visited.contains(item.id)) append(item, true);
    }
    return result;
  }

  Future<void> _showCreateChannel(List<ChatConversationModel> channels) async {
    final cubit = context.read<ChatCubit>();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _CreateChannelSheet(channels: channels, cubit: cubit),
    );
    if (created == true && mounted) {
      setState(() => _folder = _ChatFolder.channels);
    }
  }

  Future<void> _showPeople(List<ChatConversationModel> people) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                tr(context, 'Начать диалог'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (people.isEmpty)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  tr(context, 'В этом workspace пока нет доступных коллег.'),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    return ListTile(
                      leading: _Avatar(person),
                      title: Text(person.title),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openConversation(person);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        key: const Key('messenger-search'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: AppTypography.body(context),
        decoration: InputDecoration(
          hintText: MessengerListStrings.of(context).search,
          hintStyle: AppTypography.body(
            context,
          )?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          prefixIcon: Icon(
            LucideIcons.search,
            size: AppSpacing.md + AppSpacing.xs,
            color: AppColors.of(context).muted,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: tr(context, 'Очистить поиск'),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
                ),
          filled: true,
          fillColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: .045),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class _ConversationGroupHeader extends StatelessWidget {
  const _ConversationGroupHeader({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.addLabel,
  });
  final String title, addLabel;
  final int count;
  final bool expanded;
  final VoidCallback onToggle, onAdd;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.onSurface.withValues(alpha: .025),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              expanded: expanded,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
                  child: Row(
                    children: [
                      Icon(
                        expanded
                            ? LucideIcons.chevronDown
                            : LucideIcons.chevronRight,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant.withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: addLabel,
            onPressed: onAdd,
            icon: Icon(
              LucideIcons.plus,
              size: 19,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.item,
    required this.isChannel,
    required this.onTap,
    this.parentTitle,
    this.depth = 0,
    this.hasChildren = false,
    this.childrenExpanded = false,
    this.onToggleChildren,
    this.continuesBranch = false,
  });
  final ChatConversationModel item;
  final bool isChannel;
  final VoidCallback onTap;
  final String? parentTitle;
  final int depth;
  final bool hasChildren, continuesBranch, childrenExpanded;
  final VoidCallback? onToggleChildren;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strings = MessengerListStrings.of(context);
    final lastMessage = item.lastMessage;
    final isForwarded =
        lastMessage?.kind == ChatMessageKind.text &&
        lastMessage!.text.startsWith('↪ ');
    final previewMessage = isForwarded
        ? lastMessage.copyWith(text: lastMessage.text.substring(2).trimLeft())
        : lastMessage;
    final subtitleText = previewMessage != null
        ? strings.preview(previewMessage, isChannel: isChannel)
        : isChannel
        ? (parentTitle == null
              ? strings.channel
              : '${strings.subchannel} · $parentTitle')
        : item.isOnline
        ? strings.online
        : strings.personal;
    final row = ListTile(
      onTap: onTap,
      minTileHeight: depth > 0 ? 74 : 78,
      minVerticalPadding: 12,
      horizontalTitleGap: 12,
      contentPadding: EdgeInsets.only(left: 16 + depth * 36, right: 8),
      leading: isChannel
          ? ChannelAvatar(
              channelId: item.id,
              size: 54,
              imageUrl: item.imageUrl,
              repository:
                  context.read<ChatCubit>().repository is ChannelImageRepository
                  ? context.read<ChatCubit>().repository
                        as ChannelImageRepository
                  : null,
            )
          : _Avatar(item),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            if (isForwarded) ...[
              ExcludeSemantics(
                child: Icon(
                  LucideIcons.forward,
                  key: ValueKey('forwarded-preview-${item.id}'),
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                subtitleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: item.lastMessage == null && !isChannel && item.isOnline
                      ? AppColors.accent
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.unreadCount > 0) _Badge(item.unreadCount),
          if (hasChildren)
            Semantics(
              expanded: childrenExpanded,
              child: IconButton(
                key: ValueKey('channel-expand-${item.id}'),
                tooltip: tr(
                  context,
                  childrenExpanded ? 'Скрыть подканалы' : 'Показать подканалы',
                ),
                onPressed: onToggleChildren,
                icon: Icon(
                  childrenExpanded
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronRight,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ConversationMenuButton(
            key: ValueKey('conversation-menu-${item.id}'),
            conversation: item,
            repository: context.read<ChatCubit>().repository,
            chats: context.read<ChatCubit>().state is ChatLoaded
                ? (context.read<ChatCubit>().state as ChatLoaded).conversations
                : [],
            onOpen: onTap,
            onChanged: () => context.read<ChatCubit>().load(silent: true),
          ),
        ],
      ),
    );
    return Material(
      key: ValueKey('messenger-channel-row-${item.id}'),
      color: depth > 0
          ? AppColors.accent.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .055
                  : .025,
            )
          : Colors.transparent,
      child: CustomPaint(
        painter: _ChannelBranchPainter(
          depth: depth,
          hasChildren: hasChildren && childrenExpanded,
          continuesBranch: continuesBranch,
          color: colors.outlineVariant.withValues(alpha: .85),
        ),
        child: row,
      ),
    );
  }
}

class _ChannelBranchPainter extends CustomPainter {
  const _ChannelBranchPainter({
    required this.depth,
    required this.hasChildren,
    required this.continuesBranch,
    required this.color,
  });
  final int depth;
  final bool hasChildren, continuesBranch;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (depth > 0) {
      final rail = 43.0 + (depth - 1) * 36;
      final center = size.height / 2;
      final avatarStart = 16.0 + depth * 36;
      final path = Path()
        ..moveTo(rail, 0)
        ..lineTo(rail, center - 6)
        ..quadraticBezierTo(rail, center, rail + 6, center)
        ..lineTo(avatarStart - 3, center);
      canvas.drawPath(path, paint);
      if (continuesBranch) {
        canvas.drawLine(
          Offset(rail, math.max(0, center - 6)),
          Offset(rail, size.height),
          paint,
        );
      }
    }
    if (hasChildren) {
      final center = 43.0 + depth * 36;
      canvas.drawLine(
        Offset(center, size.height / 2 + 28),
        Offset(center, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChannelBranchPainter old) =>
      old.depth != depth ||
      old.hasChildren != hasChildren ||
      old.continuesBranch != continuesBranch ||
      old.color != color;
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.item);
  final ChatConversationModel item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        UserAvatar(
          size: 54,
          userId: item.id,
          name: item.title,
          avatarUrl: item.avatarUrl,
        ),
        if (item.isOnline)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF2BAC76),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.isSearch});
  final bool isSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearch ? LucideIcons.searchX : LucideIcons.messagesSquare,
              size: 34,
              color: const Color(0xFF887A89),
            ),
            const SizedBox(height: 15),
            Text(
              isSearch
                  ? tr(context, 'Ничего не найдено')
                  : tr(context, 'Чатов пока нет'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearch
                  ? tr(context, 'Попробуйте другое имя или название канала.')
                  : tr(
                      context,
                      'Каналы и коллеги вашего workspace появятся здесь.',
                    ),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: AppColors.of(context).muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.wifiOff,
              size: 34,
              color: AppColors.of(context).muted,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(tr(context, 'Повторить')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateChannelSheet extends StatefulWidget {
  const _CreateChannelSheet({required this.channels, required this.cubit});
  final List<ChatConversationModel> channels;
  final ChatCubit cubit;
  @override
  State<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<_CreateChannelSheet> {
  final _controller = TextEditingController();
  String? _parentId;
  bool _saving = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    final success = await widget.cubit.createChannel(
      _controller.text,
      parentId: _parentId,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.error,
          content: Text(tr(context, 'Введите название или повторите попытку.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'Новый канал'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        AppFormField(
          label: tr(context, 'Название канала'),
          child: TextField(
            key: const Key('channel-name-field'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: tr(context, 'Название канала'),
              prefixText: '# ',
            ),
          ),
        ),
        if (widget.channels.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppFormField(
            label: tr(context, 'Родительский канал'),
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _parentId,
              decoration: InputDecoration(
                hintText: tr(context, 'Родительский канал'),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(tr(context, 'Без вложенности')),
                ),
                ...widget.channels.map(
                  (channel) => DropdownMenuItem<String?>(
                    value: channel.id,
                    child: Text('# ${channel.title}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _parentId = value),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('create-channel-button'),
          onPressed: _saving ? null : _submit,
          child: Text(tr(context, 'Создать канал')),
        ),
      ],
    ),
  );
}
