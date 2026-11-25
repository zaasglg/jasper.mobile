import 'package:jospar/core/localization/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../profile/presentation/cubit/profile_cubit.dart';
import '../../profile/presentation/cubit/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_back_button.dart';
import '../../dashboard/presentation/widgets/dashboard_widget_skeleton.dart';
import '../../inbox/presentation/widgets/inbox_task_menu.dart';
import 'search_cubit.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Color get _canvas => AppColors.of(context).canvas;
  Color get _ink => AppColors.of(context).ink;
  Color get _muted => AppColors.of(context).muted;
  Color get _subtle => AppColors.of(context).muted;
  Color get _accent => AppColors.of(context).accent;
  Color get _border => AppColors.of(context).border;

  static const _filterLabels = <String>[
    'Все',
    'Задачи',
    'Проекты',
    'Инбокс',
    'Номер #',
  ];
  static const _defaultCounts = <int>[18, 12, 5, 7, 4];

  final _query = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedFilter = 0;
  final List<String> _recentSearches = [];
  FlutterSecureStorage? _historyPrefs;
  String? _historyKey;
  int _historyRevision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    final profile = context.read<ProfileCubit?>()?.state;
    if (profile is! ProfileLoaded) return;
    final workspace = context.read<SearchCubit>().workspaceId;
    _historyKey = 'search_history.v1.${profile.profile.id}.$workspace';
    final revision = _historyRevision;
    try {
      const prefs = FlutterSecureStorage();
      final saved = await prefs.read(key: _historyKey!);
      final entries = saved == null
          ? <String>[]
          : (jsonDecode(saved) as List).whereType<String>().take(8).toList();
      if (!mounted) return;
      _historyPrefs = prefs;
      if (revision == _historyRevision) {
        setState(() {
          _recentSearches.addAll(entries);
        });
      } else {
        _saveHistory();
      }
    } catch (_) {
      // Search remains available when local storage is unavailable.
    }
  }

  void _saveHistory() {
    _historyRevision++;
    final prefs = _historyPrefs;
    final key = _historyKey;
    if (prefs != null && key != null) {
      unawaited(
        prefs
            .write(key: key, value: jsonEncode(_recentSearches))
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addRecentSearch(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return;
    setState(() {
      _recentSearches.remove(normalized);
      _recentSearches.insert(0, normalized);
      if (_recentSearches.length > 8) {
        _recentSearches.removeRange(8, _recentSearches.length);
      }
      _saveHistory();
    });
  }

  void _applySearch(String query) {
    _query.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _addRecentSearch(query);
    context.read<SearchCubit>().changeQuery(query, immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        title: Text(
          tr(context, 'Поиск'),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<SearchCubit, SearchState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.of(context).canvas,
                    border: Border(bottom: BorderSide(color: _border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchBar(context),
                      _buildFilterChips(state),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: _border, width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: _accent, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        key: const Key('global-search-input'),
        controller: _query,
        focusNode: _focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        cursorColor: _accent,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: tr(context, 'Название задачи, #123 или проект...'),
          hintStyle: GoogleFonts.inter(fontSize: 14, color: _subtle),
          prefixIcon: Icon(LucideIcons.search, size: 19, color: _muted),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _query,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const Key('global-search-clear'),
                    tooltip: tr(context, 'Очистить поиск'),
                    icon: Icon(LucideIcons.x, size: 18, color: _muted),
                    onPressed: () {
                      _query.clear();
                      context.read<SearchCubit>().changeQuery('');
                    },
                  ),
          ),
          filled: true,
          fillColor: AppColors.of(context).subtleSurface,
          isDense: true,
          constraints: const BoxConstraints(minHeight: 48),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: focusedBorder,
        ),
        onChanged: context.read<SearchCubit>().changeQuery,
        onSubmitted: (value) {
          _addRecentSearch(value);
          context.read<SearchCubit>().changeQuery(value, immediate: true);
        },
      ),
    );
  }

  Widget _buildFilterChips(SearchState state) {
    final results = state.results;
    final hasResults = state.status == SearchStatus.success;
    final counts = hasResults
        ? <int>[
            results.tasks.length +
                results.projects.length +
                results.inbox.length,
            results.tasks.length,
            results.projects.length,
            results.inbox.length,
            results.tasks.where((t) => t.displayId.trim().isNotEmpty).length,
          ]
        : _defaultCounts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.of(context).subtleSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _filterLabels.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _FilterTab(
                  label: _filterLabels[i],
                  count: counts[i],
                  selected: _selectedFilter == i,
                  onTap: () => setState(() => _selectedFilter = i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state.status == SearchStatus.initial) {
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_recentSearches.isNotEmpty) ...[
              _buildRecentSearches(context),
              const SizedBox(height: 16),
            ],
            _buildEmptyState(context),
          ],
        ),
      );
    }
    if (state.status == SearchStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: DashboardWidgetSkeleton(),
      );
    }
    if (state.status == SearchStatus.failure) {
      return _StatusCard(
        icon: LucideIcons.wifiOff,
        title: 'Не удалось выполнить поиск',
        text: 'Проверьте подключение и попробуйте ещё раз.',
        action: TextButton(
          onPressed: () => context.read<SearchCubit>().changeQuery(
            _query.text,
            immediate: true,
          ),
          child: Text(tr(context, 'Повторить')),
        ),
      );
    }
    if (state.results.isEmpty) {
      return _StatusCard(
        icon: LucideIcons.searchX,
        illustration: true,
        title: 'Ничего не найдено',
        text:
            'По запросу «${state.query}». Попробуйте другое название или номер задачи.',
      );
    }

    final results = state.results;
    final numberedTasks = results.tasks
        .where((task) => task.displayId.trim().isNotEmpty)
        .toList(growable: false);
    final showTasks = _selectedFilter == 0 || _selectedFilter == 1;
    final showProjects = _selectedFilter == 0 || _selectedFilter == 2;
    final showInbox = _selectedFilter == 0 || _selectedFilter == 3;
    final showNumbered = _selectedFilter == 4;

    final entries = <Widget>[
      if (results.failedSources.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            tr(
              context,
              "Не удалось загрузить: {p0}. Показаны доступные результаты.",
              {'p0': results.failedSources.join(', ')},
            ),
            style: GoogleFonts.inter(fontSize: 13, color: _muted),
          ),
        ),
      if (showTasks && results.tasks.isNotEmpty) ...[
        _SearchHeading(tr(context, 'Задачи'), results.tasks.length),
        for (final task in results.tasks)
          _SearchResult(
            icon: LucideIcons.circleCheck,
            title: task.title,
            subtitle: [
              task.displayId,
              if (task.archived) 'В архиве',
            ].where((s) => s.isNotEmpty).join(' · '),
            onTap: () => context.push('/tasks/${task.id}', extra: task),
          ),
      ],
      if (showNumbered && numberedTasks.isNotEmpty) ...[
        _SearchHeading(tr(context, 'По номеру #'), numberedTasks.length),
        for (final task in numberedTasks)
          _SearchResult(
            icon: LucideIcons.hash,
            title: task.title,
            subtitle: [
              task.displayId,
              if (task.archived) 'В архиве',
            ].where((s) => s.isNotEmpty).join(' · '),
            onTap: () => context.push('/tasks/${task.id}', extra: task),
          ),
      ],
      if (showProjects && results.projects.isNotEmpty) ...[
        _SearchHeading(tr(context, 'Проекты'), results.projects.length),
        for (final project in results.projects)
          _SearchResult(
            icon: LucideIcons.folder,
            title: project.name,
            subtitle: project.code,
            onTap: () =>
                context.push('/projects/${project.id}', extra: project),
          ),
      ],
      if (showInbox && results.inbox.isNotEmpty) ...[
        _SearchHeading(tr(context, 'Инбокс'), results.inbox.length),
        for (final task in results.inbox)
          _SearchResult(
            icon: LucideIcons.inbox,
            title: task.title,
            subtitle: task.displayId,
            onTap: () => showInboxTaskCard(context, task),
          ),
      ],
    ];

    final hasVisibleResults = entries.any((w) => w is _SearchResult);
    if (!hasVisibleResults) {
      return _StatusCard(
        icon: LucideIcons.search,
        illustration: true,
        title: 'В этом разделе ничего не найдено',
        text: 'Переключитесь на «Все» или попробуйте другой фильтр.',
        action: TextButton(
          onPressed: () => setState(() => _selectedFilter = 0),
          child: Text(tr(context, 'Показать все')),
        ),
      );
    }

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) => entries[index],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr(context, 'НЕДАВНИЕ ПОИСКИ'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: _muted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _recentSearches.clear();
                _saveHistory();
              }),
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(tr(context, 'Очистить')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _recentSearches)
              Material(
                color: AppColors.of(context).canvas,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _applySearch(item),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clock, size: 14, color: _subtle),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 210),
                          child: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() {
                            _recentSearches.remove(item);
                            _saveHistory();
                          }),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              LucideIcons.x,
                              size: 14,
                              color: _subtle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.of(context).canvas,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/search_empty.png',
            width: 132,
            height: 132,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.of(context).badgeSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(LucideIcons.search, size: 28, color: _accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(context, 'Найдите нужное'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'Введите название задачи, номер или фразу для быстрого поиска по проектам и записям Инбокса.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: _muted),
          ),
          const SizedBox(height: 12),
          _buildSuggestionsList(context),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(BuildContext context) {
    return Column(
      children: [
        _SuggestionTile(
          icon: LucideIcons.hash,
          iconBg: AppColors.of(context).badgeSurface,
          iconColor: _accent,
          title: 'Поиск по номеру задачи',
          subtitle: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 12, color: _muted),
              children: [
                TextSpan(text: tr(context, 'Наберите например ')),
                TextSpan(
                  text: '#123',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
          onTap: () {
            setState(() => _selectedFilter = 4);
            _query.value = const TextEditingValue(
              text: '#',
              selection: TextSelection.collapsed(offset: 1),
            );
            _focusNode.requestFocus();
          },
        ),
        const SizedBox(height: 6),
        _SuggestionTile(
          icon: LucideIcons.tag,
          iconBg: const Color(0xFFECFDF5),
          iconColor: const Color(0xFF10B981),
          title: 'Быстрые теги и проекты',
          subtitle: Text(
            tr(context, 'Фильтруйте по названию проекта'),
            style: GoogleFonts.inter(fontSize: 12, color: _muted),
          ),
          onTap: () {
            setState(() => _selectedFilter = 2);
            _focusNode.requestFocus();
          },
        ),
        const SizedBox(height: 6),
        _SuggestionTile(
          icon: LucideIcons.inbox,
          iconBg: const Color(0xFFFFFBEB),
          iconColor: const Color(0xFFD97706),
          title: 'Записи в Инбоксе',
          subtitle: Text(
            tr(context, 'Поиск по быстрым заметкам и идеям'),
            style: GoogleFonts.inter(fontSize: 12, color: _muted),
          ),
          onTap: () {
            setState(() => _selectedFilter = 3);
            _focusNode.requestFocus();
          },
        ),
      ],
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.of(context).badgeSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      shadowColor: const Color(0x140F172A),
      elevation: selected ? 1 : 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(context, label),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppColors.of(context).ink
                      : AppColors.of(context).muted,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.of(context).accent
                      : AppColors.of(context).border,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.of(context).onAccent
                        : AppColors.of(context).muted,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Widget subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.of(context).subtleSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? iconColor.withValues(alpha: .12)
                      : iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.of(context).ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    subtitle,
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.of(context).muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHeading extends StatelessWidget {
  const _SearchHeading(this.text, this.count);

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(
      '$text · $count',
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.of(context).muted,
      ),
    ),
  );
}

class _SearchResult extends StatelessWidget {
  const _SearchResult({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.of(context).canvas,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.of(context).border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 21, color: AppColors.of(context).muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle.isNotEmpty) ...[
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.of(context).muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: AppColors.of(context).ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppColors.of(context).muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.illustration = false,
  });

  final IconData icon;
  final bool illustration;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.of(context).canvas,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration)
              Image.asset(
                'assets/images/search_empty.png',
                width: 148,
                height: 148,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) =>
                    Icon(icon, size: 48, color: AppColors.of(context).accent),
              )
            else
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.of(context).badgeSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: AppColors.of(context).accent,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: AppColors.of(context).muted,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    ),
  );
}
