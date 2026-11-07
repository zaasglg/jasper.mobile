import '../widgets/conversation_menu.dart';
import '../widgets/messenger_refresh_lifecycle.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../../../core/widgets/app_form_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/models/chat_conversation_model.dart';
import '../cubit/chat_cubit.dart';
import '../../../shell/presentation/screens/main_shell.dart';

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
  bool _channelsExpanded = true;
  bool _peopleExpanded = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFD),
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            _Search(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
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
                  final channels = filtered
                      .where((item) => item.isChannel)
                      .toList();
                  final people = filtered
                      .where((item) => !item.isChannel)
                      .toList();
                  if (channels.isEmpty && people.isEmpty && _query.isNotEmpty) {
                    return const _NoResults(isSearch: true);
                  }
                  final mentions = conversations.fold<int>(
                    0,
                    (sum, item) => sum + item.unreadCount,
                  );
                  return RefreshIndicator(
                    onRefresh: context.read<ChatCubit>().load,
                    child: ListView(
                      key: const Key('messenger-list'),
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        if (_query.isEmpty) ...[
                          const SizedBox(height: 10),
                          _Shortcut(
                            icon: LucideIcons.atSign,
                            label: 'Упоминания и реакции',
                            count: mentions == 0 ? null : mentions,
                            onTap: () => context.push('/activity/mentions'),
                          ),
                          _Shortcut(
                            icon: LucideIcons.bookmark,
                            label: 'Сохранённое',
                            onTap: () => context.push('/activity/saved'),
                          ),
                          _Shortcut(
                            icon: LucideIcons.archive,
                            label: 'Кладовка',
                            onTap: () => context.push('/messenger-storage'),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 9),
                            child: Divider(height: 1, color: Color(0xFFE9E4E9)),
                          ),
                        ],
                        if (_query.isEmpty || channels.isNotEmpty)
                          _Section(
                            title: 'Каналы',
                            items: _orderedChannels(channels),
                            isChannel: true,
                            expanded: _channelsExpanded,
                            onToggle: () => setState(
                              () => _channelsExpanded = !_channelsExpanded,
                            ),
                            onAdd: () => _showCreateChannel(channels),
                            onTap: _openConversation,
                          ),
                        if (_query.isEmpty || people.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _Section(
                            title: 'Личные сообщения',
                            items: people,
                            expanded: _peopleExpanded,
                            onToggle: () => setState(
                              () => _peopleExpanded = !_peopleExpanded,
                            ),
                            onAdd: () => _showPeople(people),
                            onTap: _openConversation,
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
    void append(String? parentId, Set<String> visited) {
      for (final item in byParent[parentId] ?? const []) {
        if (!visited.add(item.id)) continue;
        result.add(item);
        append(item.id, visited);
      }
    }

    append(null, <String>{});
    for (final item in channels) {
      if (!result.contains(item)) result.add(item);
    }
    return result;
  }

  Future<void> _showCreateChannel(List<ChatConversationModel> channels) async {
    final cubit = context.read<ChatCubit>();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _CreateChannelSheet(channels: channels, cubit: cubit),
    );
    if (created == true && mounted) {
      setState(() => _channelsExpanded = true);
    }
  }

  Future<void> _showPeople(List<ChatConversationModel> people) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'Начать диалог',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (people.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('В этом workspace пока нет доступных коллег.'),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accent,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Открыть меню',
            onPressed: MainShell.openDrawer,
            icon: const Icon(
              LucideIcons.menu,
              color: Colors.white,
              size: AppIconSizes.standard,
            ),
          ),
          Expanded(
            child: Text(
              'Мессенджер',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
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
      color: AppColors.accent,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 13),
      child: TextField(
        key: const Key('messenger-search'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.manrope(fontSize: 14, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Поиск',
          hintStyle: GoogleFonts.manrope(
            fontSize: 14,
            color: const Color(0xFF6E5B70),
          ),
          prefixIcon: const Icon(
            LucideIcons.search,
            size: AppIconSizes.standard,
            color: Color(0xFF6E5B70),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Очистить поиск',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(LucideIcons.x, size: AppIconSizes.standard),
                ),
          filled: true,
          fillColor: const Color(0xFFF7F3F7),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
  });
  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      minTileHeight: 43,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      leading: Icon(
        icon,
        size: AppIconSizes.standard,
        color: const Color(0xFF4A364B),
      ),
      title: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      trailing: count == null ? null : _Badge(count!),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.onTap,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    this.isChannel = false,
  });
  final String title;
  final List<ChatConversationModel> items;
  final ValueChanged<ChatConversationModel> onTap;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final bool isChannel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          key: ValueKey(
            'messenger-section-${isChannel ? 'channels' : 'people'}',
          ),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 5),
            child: Row(
              children: [
                Icon(
                  expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: AppIconSizes.standard,
                  color: Color(0xFF6F6570),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4A364B),
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey(
                    'messenger-add-${isChannel ? 'channel' : 'person'}',
                  ),
                  tooltip: 'Добавить',
                  visualDensity: VisualDensity.compact,
                  onPressed: onAdd,
                  icon: const Icon(
                    LucideIcons.plus,
                    size: AppIconSizes.standard,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final item in items)
            _Conversation(
              item: item,
              isChannel: isChannel,
              depth: isChannel ? _depthOf(item, items) : 0,
              onTap: () => onTap(item),
            ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 3),
            child: InkWell(
              key: ValueKey(
                'messenger-add-row-${isChannel ? 'channel' : 'person'}',
              ),
              onTap: onAdd,
              borderRadius: BorderRadius.circular(7),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EEF1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isChannel ? LucideIcons.plus : LucideIcons.userPlus,
                        size: AppIconSizes.standard,
                        color: const Color(0xFF5E4B60),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      isChannel ? 'Добавить канал' : 'Добавить коллег',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: const Color(0xFF5E4B60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _depthOf(
    ChatConversationModel item,
    List<ChatConversationModel> channels,
  ) {
    var parentId = item.parentId;
    var depth = 0;
    final visited = <String>{item.id};
    while (parentId != null && depth < 4 && visited.add(parentId)) {
      depth++;
      ChatConversationModel? parent;
      for (final entry in channels) {
        if (entry.id == parentId) {
          parent = entry;
          break;
        }
      }
      parentId = parent?.parentId;
    }
    return depth;
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.item,
    required this.isChannel,
    required this.onTap,
    this.depth = 0,
  });
  final ChatConversationModel item;
  final bool isChannel;
  final VoidCallback onTap;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      minTileHeight: 42,
      horizontalTitleGap: 11,
      contentPadding: EdgeInsets.only(left: 18 + depth * 22, right: 18),
      leading: isChannel
          ? const SizedBox(
              width: 27,
              child: Icon(
                LucideIcons.hash,
                size: AppIconSizes.standard,
                color: Color(0xFF756A76),
              ),
            )
          : _Avatar(item),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: item.unreadCount > 0 ? FontWeight.w800 : FontWeight.w500,
          color: item.unreadCount > 0 ? AppColors.ink : const Color(0xFF554B56),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.unreadCount > 0) _Badge(item.unreadCount),
          ConversationMenuButton(
            key: ValueKey('conversation-menu-${item.id}'),
            conversation: item,
            repository: context.read<ChatCubit>().repository,
            chats: context.read<ChatCubit>().state is ChatLoaded
                ? (context.read<ChatCubit>().state as ChatLoaded).conversations
                : const [],
            onOpen: onTap,
            onChanged: () => context.read<ChatCubit>().load(silent: true),
          ),
        ],
      ),
    );
  }
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
          size: 28,
          userId: item.id,
          name: item.title,
          avatarUrl: item.avatarUrl,
        ),
        if (item.isOnline)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFF2BAC76),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
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
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFCD2553),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.manrope(
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
              isSearch ? 'Ничего не найдено' : 'Чатов пока нет',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearch
                  ? 'Попробуйте другое имя или название канала.'
                  : 'Каналы и коллеги вашего workspace появятся здесь.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.45,
                color: AppColors.muted,
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
            const Icon(LucideIcons.wifiOff, size: 34, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: AppColors.ink, fontSize: 14),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Повторить'),
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
        const SnackBar(
          content: Text('Введите название или повторите попытку.'),
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
          'Новый канал',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        AppFormField(
          label: 'Название канала',
          child: TextField(
            key: const Key('channel-name-field'),
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Название канала',
              prefixText: '# ',
            ),
          ),
        ),
        if (widget.channels.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppFormField(
            label: 'Родительский канал',
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _parentId,
              decoration: const InputDecoration(hintText: 'Родительский канал'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Без вложенности'),
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
          child: const Text('Создать канал'),
        ),
      ],
    ),
  );
}
