import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/screens/main_shell.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  _ChatFilter _selectedFilter = _ChatFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Открыть меню',
          onPressed: MainShell.openDrawer,
          icon: const Icon(Icons.menu_rounded, color: AppColors.ink),
        ),
        title: Text(
          'Мессенджер',
          style: GoogleFonts.manrope(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.35,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: _ChatSearchField(controller: _searchController),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _ChatFilters(
                selected: _selectedFilter,
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Text(
                    _selectedFilter.sectionTitle,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _ConversationCount(count: 0),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _EmptyConversations(
                  key: ValueKey<_ChatFilter>(_selectedFilter),
                  filter: _selectedFilter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSearchField extends StatelessWidget {
  const _ChatSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('messenger-search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.manrope(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: 'Поиск диалогов',
        hintStyle: GoogleFonts.manrope(fontSize: 14, color: AppColors.muted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 21,
          color: AppColors.muted,
        ),
        filled: true,
        fillColor: AppColors.subtleSurface,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.25),
        ),
      ),
    );
  }
}

class _ChatFilters extends StatelessWidget {
  const _ChatFilters({required this.selected, required this.onSelected});

  final _ChatFilter selected;
  final ValueChanged<_ChatFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _ChatFilter.values.map((filter) {
        final isSelected = filter == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: filter == _ChatFilter.values.last ? 0 : 6,
            ),
            child: _FilterButton(
              filter: filter,
              isSelected: isSelected,
              onPressed: () => onSelected(filter),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.filter,
    required this.isSelected,
    required this.onPressed,
  });

  final _ChatFilter filter;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Material(
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.09)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.border,
          ),
        ),
        child: InkWell(
          key: ValueKey<String>('messenger-filter-${filter.name}'),
          borderRadius: BorderRadius.circular(9),
          onTap: onPressed,
          child: Center(
            child: Text(
              filter.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.accent : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationCount extends StatelessWidget {
  const _ConversationCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.badgeSurface,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations({super.key, required this.filter});

  final _ChatFilter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(filter.icon, size: 31, color: AppColors.accent),
              ),
              const SizedBox(height: 20),
              Text(
                filter.emptyTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filter.emptyDescription,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ChatFilter {
  all,
  unread,
  groups;

  String get label => switch (this) {
    _ChatFilter.all => 'Все',
    _ChatFilter.unread => 'Непрочитанные',
    _ChatFilter.groups => 'Группы',
  };

  String get sectionTitle => switch (this) {
    _ChatFilter.all => 'Диалоги',
    _ChatFilter.unread => 'Непрочитанные',
    _ChatFilter.groups => 'Групповые чаты',
  };

  String get emptyTitle => switch (this) {
    _ChatFilter.all => 'Диалогов пока нет',
    _ChatFilter.unread => 'Всё прочитано',
    _ChatFilter.groups => 'Групповых чатов нет',
  };

  String get emptyDescription => switch (this) {
    _ChatFilter.all =>
      'Личные и групповые переписки команды появятся на этом экране.',
    _ChatFilter.unread => 'Новые сообщения появятся здесь после получения.',
    _ChatFilter.groups =>
      'Здесь будут отображаться обсуждения проектов и рабочих групп.',
  };

  IconData get icon => switch (this) {
    _ChatFilter.all => Icons.forum_outlined,
    _ChatFilter.unread => Icons.mark_chat_read_outlined,
    _ChatFilter.groups => Icons.groups_2_outlined,
  };
}
