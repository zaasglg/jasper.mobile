import 'package:jospar/core/localization/app_translations.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_snack_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/app_action_menu.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../chat/data/services/chat_media_payload.dart';
import '../domain/entities/storage_scope.dart';
import '../domain/entities/storage_item.dart';
import '../domain/entities/storage_enums.dart';
import '../domain/storage_repository.dart';
import 'storage_cubit.dart';
import 'storage_file_screen.dart';

class StorageScreen extends StatelessWidget {
  const StorageScreen({required this.scope, super.key});
  final StorageScope scope;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StorageCubit(sl<StorageRepository>(), scope)..load(),
    child: _StorageBody(scope: scope),
  );
}

class _StorageBody extends StatefulWidget {
  const _StorageBody({required this.scope});
  final StorageScope scope;
  @override
  State<_StorageBody> createState() => _StorageBodyState();
}

class _StorageBodyState extends State<_StorageBody> {
  StorageCategory _category = StorageCategory.media;
  bool _grid = true;
  String _query = '';
  String? _author;
  StorageCubit get cubit => context.read<StorageCubit>();
  static const labels = {
    StorageCategory.media: 'Медиа',
    StorageCategory.documents: 'Документы',
    StorageCategory.links: 'Ссылки',
    StorageCategory.favorites: 'Избранное',
    StorageCategory.summaries: 'Резюме встреч',
  };
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  static const _searchBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide.none,
  );
  Widget _categorySegment(StorageCategory category, int count) {
    final selected = category == _category;
    final color = selected
        ? Theme.of(context).colorScheme.onSurface
        : AppColors.of(context).muted;
    return Semantics(
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                labels[category]!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
              if (category != StorageCategory.summaries || count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent
                        : (_dark ? Colors.white12 : const Color(0xFFE8E8EF)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? Colors.white
                          : AppColors.of(context).muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _upload() async {
    await cubit.action(() async {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      for (final file in files) {
        final size = await file.length();
        if (size != null && size > ChatMediaPayload.maxFileBytes) {
          throw const StorageException('Максимальный размер файла — 25 МБ');
        }
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        await cubit.repository.upload(widget.scope, file.name, bytes);
      }
      await cubit.load();
    });
  }

  Future<void> _menu(StorageItem item) async {
    final state = cubit.state;
    final action = await showAppActionMenu<String>(
      context,
      title: item.name,
      groups: [
        [
          if (item.canOpen)
            AppMenuAction(
              value: 'open',
              label: item.kind == StorageFileKind.link
                  ? tr(context, 'Открыть ссылку')
                  : tr(context, 'Просмотреть'),
              icon: LucideIcons.externalLink,
            ),
          AppMenuAction(
            value: 'favorite',
            label: state.favorites.contains(item.id)
                ? tr(context, 'Убрать из избранного')
                : tr(context, 'В избранное'),
            icon: LucideIcons.star,
          ),
          if (item.canOpen && item.kind != StorageFileKind.link)
            AppMenuAction(
              value: 'download',
              label: tr(context, 'Скачать'),
              icon: LucideIcons.download,
            ),
          if (item.taskId != null || item.messageId != null)
            AppMenuAction(
              value: 'source',
              label: item.taskId != null
                  ? tr(context, 'Открыть задачу')
                  : tr(context, 'Перейти к сообщению'),
              icon: LucideIcons.arrowRight,
            ),
          if (item.canAnalyze && item.canOpen)
            AppMenuAction(
              value: 'analyze',
              label: tr(context, 'Создать задачи из файла'),
              icon: LucideIcons.sparkles,
            ),
        ],
        [
          if (widget.scope.source == StorageSource.chat &&
              item.authorId == state.userId)
            AppMenuAction(
              value: 'delete',
              label: tr(context, 'Удалить сообщение с файлом'),
              icon: LucideIcons.trash2,
              destructive: true,
            ),
        ],
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _open(item);
      case 'favorite':
        await cubit.favorite(item);
      case 'download':
        await cubit.action(
          () => saveStorageFile(cubit.repository, widget.scope, item),
        );
      case 'source':
        if (item.taskId != null) {
          await context.push('/tasks/${Uri.encodeComponent(item.taskId!)}');
        } else {
          context.pop(item.messageId);
        }
      case 'delete':
        if (await showAppConfirmation(
              context,
              tr(context, 'Удалить файл?'),
              tr(
                context,
                'Сообщение с этим вложением будет удалено из переписки.',
              ),
              confirmLabel: 'Удалить',
              destructive: true,
            ) &&
            mounted) {
          await cubit.delete(item);
        }
      case 'analyze':
        if (!await showAppConfirmation(
              context,
              tr(context, 'Создать задачи из файла?'),
              tr(
                context,
                'Документ будет распознан, а найденные задачи появятся в инбоксе этого workspace.',
              ),
              confirmLabel: 'Создать задачи',
            ) ||
            !mounted) {
          return;
        }
        final result = await cubit.analyze(item);
        if (!mounted || result == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: result.alreadyImported
                ? AppSnackBarTone.info
                : AppSnackBarTone.success,
            content: Text(
              result.alreadyImported
                  ? tr(context, 'Документ уже обработан')
                  : tr(context, "Создано задач: {p0}", {'p0': result.created}),
            ),
            action: result.undoBatchId == null
                ? null
                : SnackBarAction(
                    label: tr(context, 'Отменить'),
                    onPressed: () => cubit.action(
                      () => cubit.repository.undoImport(
                        widget.scope,
                        result.undoBatchId!,
                      ),
                    ),
                  ),
          ),
        );
    }
  }

  Future<void> _open(StorageItem item) async {
    if (item.kind == StorageFileKind.link) {
      await cubit.action(() => openStorageLink(item.url ?? ''));
    } else if (item.canOpen) {
      await context.push('/storage-file', extra: (widget.scope, item));
    } else {
      await _menu(item);
    }
  }

  Future<void> _filter(StorageState state) async {
    final people = {
      for (final item in state.items.where((e) => e.authorId.isNotEmpty))
        item.authorId: item.authorName.isEmpty ? 'Участник' : item.authorName,
    };
    final selected = await showAppActionMenu<String>(
      context,
      title: 'Автор',
      groups: [
        [
          AppMenuAction(
            value: '',
            label: tr(context, 'Все участники'),
            icon: LucideIcons.users,
            selected: _author == null,
          ),
          for (final person in people.entries)
            AppMenuAction(
              value: person.key,
              label: person.value,
              icon: LucideIcons.user,
              selected: _author == person.key,
            ),
        ],
      ],
    );
    if (mounted && selected != null) {
      setState(() => _author = selected.isEmpty ? null : selected);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<StorageCubit, StorageState>(
    listener: (context, state) {
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(tr(context, state.error!)),
          ),
        );
      }
    },
    builder: (context, state) {
      final categories = StorageCategory.values.where(
        (e) =>
            widget.scope.source == StorageSource.chat ||
            e != StorageCategory.summaries,
      );
      bool matches(StorageItem item) =>
          (_author == null || item.authorId == _author) &&
          '${item.name} ${item.taskTitle} ${item.taskDisplayId} ${item.authorName}'
              .toLowerCase()
              .contains(_query);
      final filtered = state.items.where(matches).toList();
      int count(StorageCategory category) =>
          category == StorageCategory.summaries
          ? state.summaryTotal
          : filtered
                .where(
                  (e) => category == StorageCategory.favorites
                      ? state.favorites.contains(e.id)
                      : e.category == category,
                )
                .length;
      final items = filtered
          .where(
            (e) => _category == StorageCategory.favorites
                ? state.favorites.contains(e.id)
                : e.category == _category,
          )
          .toList();
      final groups = <String, List<StorageItem>>{};
      for (final item in items) {
        final key = storageMonth(item.date);
        (groups[key] ??= []).add(item);
      }
      return Scaffold(
        backgroundColor: _dark
            ? Theme.of(context).colorScheme.surface
            : AppColors.of(context).quietSurface,
        appBar: AppBar(
          toolbarHeight:
              56 +
              (MediaQuery.textScalerOf(context).scale(18) - 18).clamp(0, 36) *
                  1.8,
          backgroundColor: _dark
              ? Theme.of(context).colorScheme.surface
              : Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          leading: AppBackButton(onPressed: context.pop),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'Кладовка'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                widget.scope.title,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.of(context).muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: tr(context, 'Обновить'),
              onPressed: state.loading
                  ? null
                  : () {
                      cubit.load();
                      if (_category == StorageCategory.summaries) {
                        cubit.loadSummaries();
                      }
                    },
              icon: const Icon(LucideIcons.refreshCw, size: 16),
            ),
            if (widget.scope.source == StorageSource.chat)
              IconButton(
                tooltip: tr(context, 'Добавить файл'),
                onPressed: state.busy ? null : _upload,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 20),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: tr(context, 'Поиск файлов'),
                          hintStyle: TextStyle(
                            color: AppColors.of(context).muted,
                            fontSize: 13,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: _dark
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : const Color(0xFFF5F5F8),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 16,
                            color: AppColors.of(context).muted,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 42,
                          ),
                          border: _searchBorder,
                          enabledBorder: _searchBorder,
                          focusedBorder: _searchBorder.copyWith(
                            borderSide: const BorderSide(
                              color: AppColors.accent,
                              width: 1,
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: _author != null
                            ? AppColors.accent.withValues(alpha: .09)
                            : Colors.transparent,
                        foregroundColor: AppColors.of(context).muted,
                      ),
                      tooltip: tr(context, 'Фильтр по автору'),
                      onPressed: () => _filter(state),
                      icon: Icon(
                        LucideIcons.slidersHorizontal,
                        size: 16,
                        color: _author != null
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    IconButton(
                      tooltip: _grid
                          ? tr(context, 'Списком')
                          : tr(context, 'Плиткой'),
                      onPressed: () => setState(() => _grid = !_grid),
                      icon: Icon(
                        _grid ? LucideIcons.list : LucideIcons.layoutGrid,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: CupertinoSlidingSegmentedControl<StorageCategory>(
                    groupValue: _category,
                    padding: const EdgeInsets.all(4),
                    backgroundColor: _dark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF1F3F7),
                    thumbColor: _dark
                        ? const Color(0xFF636366)
                        : Theme.of(context).colorScheme.surface,
                    onValueChanged: (category) {
                      if (category == null || category == _category) return;
                      setState(() => _category = category);
                      if (category == StorageCategory.summaries) {
                        cubit.loadSummaries();
                      }
                    },
                    children: {
                      for (final category in categories)
                        category: _categorySegment(category, count(category)),
                    },
                  ),
                ),
              ),
              if (widget.scope.source == StorageSource.project &&
                  _category == StorageCategory.favorites)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    tr(
                      context,
                      'Избранное проекта хранится на этом устройстве',
                    ),
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              if (state.loading || state.busy)
                const LinearProgressIndicator(minHeight: 2),
              if (state.progress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(state.progress),
                ),
              Expanded(
                child: _category == StorageCategory.summaries
                    ? _summaries(state)
                    : state.items.isEmpty && state.loading
                    ? Center(child: Text(tr(context, 'Собираем файлы…')))
                    : state.items.isEmpty && state.error != null
                    ? Center(
                        child: TextButton(
                          onPressed: cubit.load,
                          child: Text(tr(context, 'Повторить загрузку')),
                        ),
                      )
                    : items.isEmpty
                    ? Center(child: Text(tr(context, 'Здесь пока нет файлов')))
                    : RefreshIndicator(
                        onRefresh: cubit.load,
                        child: CustomScrollView(
                          slivers: [
                            for (final group in groups.entries) ...[
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  12,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Text(
                                    group.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.of(context).muted,
                                    ),
                                  ),
                                ),
                              ),
                              if (_grid)
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  sliver: SliverGrid(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) =>
                                          _tile(group.value[index], state),
                                      childCount: group.value.length,
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 280,
                                          mainAxisExtent:
                                              180 +
                                              (MediaQuery.textScalerOf(
                                                        context,
                                                      ).scale(12) -
                                                      12) *
                                                  4,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                  ),
                                )
                              else
                                SliverList.builder(
                                  itemCount: group.value.length,
                                  itemBuilder: (context, index) => _tile(
                                    group.value[index],
                                    state,
                                    list: true,
                                  ),
                                ),
                            ],
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 24),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _summaries(StorageState state) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (state.loadingSummaries) const LinearProgressIndicator(minHeight: 2),
      if (state.summaries.isEmpty &&
          !state.loadingSummaries &&
          state.error != null)
        TextButton(
          onPressed: () => cubit.loadSummaries(),
          child: Text(tr(context, 'Повторить загрузку резюме')),
        ),
      if (state.summaries.isEmpty &&
          !state.loadingSummaries &&
          state.error == null)
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text(tr(context, 'Резюме встреч пока нет'))),
        ),
      for (final item in state.summaries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.fileText, size: 16),
          title: Text(
            item.number.isEmpty ? tr(context, 'Резюме встречи') : item.number,
          ),
          subtitle: Text(
            '${'${item.date.day} ${storageMonth(item.date.toLocal())}'} · ${item.authorName}',
          ),
          trailing: const Icon(LucideIcons.chevronRight, size: 16),
          onTap: () =>
              context.push('/storage-summary', extra: (widget.scope, item)),
        ),
      if (state.summaries.length < state.summaryTotal)
        TextButton(
          onPressed: state.loadingSummaries
              ? null
              : () => cubit.loadSummaries(more: true),
          child: Text(tr(context, 'Загрузить ещё')),
        ),
    ],
  );
  Widget _tile(StorageItem item, StorageState state, {bool list = false}) {
    final icon = switch (item.kind) {
      StorageFileKind.image => LucideIcons.image,
      StorageFileKind.video => LucideIcons.circlePlay,
      StorageFileKind.audio => LucideIcons.music2,
      StorageFileKind.link => LucideIcons.link,
      _ => LucideIcons.fileText,
    };
    final menu = IconButton(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      color: AppColors.of(context).muted,
      tooltip: tr(context, 'Действия с файлом'),
      onPressed: state.busy ? null : () => _menu(item),
      icon: const Icon(LucideIcons.ellipsis, size: 16),
    );
    final metadata = [
      item.sizeLabel,
      item.authorName,
      item.taskDisplayId,
    ].where((e) => e.isNotEmpty).join(' · ');
    if (list) {
      return ListTile(
        leading: Icon(icon, size: 20),
        title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(metadata, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: menu,
        onTap: () => _open(item),
      );
    }
    Widget preview = Icon(
      icon,
      size: 24,
      color: Theme.of(context).colorScheme.primary,
    );
    if (item.kind == StorageFileKind.image) {
      final data = item.dataUrl;
      if (data != null && data.startsWith('data:image/')) {
        try {
          preview = Image.memory(
            UriData.parse(data).contentAsBytes(),
            fit: BoxFit.cover,
            width: double.infinity,
            cacheWidth: 400,
            errorBuilder: (_, _, _) => Icon(icon, size: 20),
          );
        } catch (_) {
          /* Show the file icon for damaged thumbnails. */
        }
      } else if (data != null && Uri.tryParse(data)?.scheme == 'https') {
        preview = CachedNetworkImage(
          imageUrl: data,
          fit: BoxFit.cover,
          width: double.infinity,
          memCacheWidth: 400,
          errorWidget: (_, _, _) => Icon(icon, size: 20),
        );
      }
    }
    return Material(
      color: _dark
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .045),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    if (item.kind == StorageFileKind.image &&
                        item.dataUrl != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _dark
                                      ? Colors.white.withValues(alpha: .1)
                                      : Colors.black.withValues(alpha: .1),
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (state.favorites.contains(item.id))
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: Icon(
                          LucideIcons.star,
                          size: 16,
                          color: Color(0xFF7660E4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 0, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  menu,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                metadata,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.of(context).muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String storageMonth(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Без даты';
  const months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
