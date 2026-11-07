import '../../../core/theme/app_icon_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_ui_tokens.dart';
import '../../../core/theme/dashboard_surface.dart';
import '../../dashboard/presentation/widgets/dashboard_widget_skeleton.dart';
import '../../inbox/presentation/widgets/inbox_task_menu.dart';
import 'search_cubit.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DashboardSurface.background,
    appBar: AppBar(
      backgroundColor: DashboardSurface.background,
      surfaceTintColor: Colors.transparent,
      title: const Text('Поиск'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(
          AppSpacing.touchTarget + AppSpacing.lg,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: TextField(
            key: const Key('global-search-input'),
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: AppTypography.body(context),
            decoration: InputDecoration(
              hintText: 'Название или номер задачи',
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: AppIconSizes.standard,
              ),
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _query,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        key: const Key('global-search-clear'),
                        tooltip: 'Очистить поиск',
                        icon: const Icon(
                          Icons.close,
                          size: AppIconSizes.standard,
                        ),
                        onPressed: () {
                          _query.clear();
                          context.read<SearchCubit>().changeQuery('');
                        },
                      ),
              ),
            ),
            onChanged: context.read<SearchCubit>().changeQuery,
            onSubmitted: (value) =>
                context.read<SearchCubit>().changeQuery(value, immediate: true),
          ),
        ),
      ),
    ),
    body: BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        if (state.status == SearchStatus.initial) {
          return const _Message(
            icon: Icons.search,
            title: 'Найдите нужное',
            text: 'Введите название задачи, проекта или запись из Инбокса.',
          );
        }
        if (state.status == SearchStatus.loading) {
          return const DashboardWidgetSkeleton();
        }
        if (state.status == SearchStatus.failure) {
          return _Message(
            icon: Icons.wifi_off_outlined,
            title: 'Не удалось выполнить поиск',
            text: 'Проверьте подключение и попробуйте ещё раз.',
            action: TextButton(
              onPressed: () => context.read<SearchCubit>().changeQuery(
                _query.text,
                immediate: true,
              ),
              child: const Text('Повторить'),
            ),
          );
        }
        if (state.results.isEmpty) {
          return _Message(
            icon: Icons.search_off,
            title: 'Ничего не найдено',
            text:
                'По запросу «${state.query}». Попробуйте другое название или номер задачи.',
          );
        }
        final results = state.results;
        final entries = <Widget>[
          if (results.failedSources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Не удалось загрузить: ${results.failedSources.join(', ')}. Показаны доступные результаты.',
              ),
            ),
          if (results.tasks.isNotEmpty) ...[
            _SearchHeading('Задачи', results.tasks.length),
            for (final task in results.tasks)
              _SearchResult(
                icon: Icons.task_alt,
                title: task.title,
                subtitle: [
                  task.displayId,
                  if (task.archived) 'В архиве',
                ].where((s) => s.isNotEmpty).join(' · '),
                onTap: () => context.push('/tasks/${task.id}', extra: task),
              ),
          ],
          if (results.projects.isNotEmpty) ...[
            _SearchHeading('Проекты', results.projects.length),
            for (final project in results.projects)
              _SearchResult(
                icon: Icons.folder_outlined,
                title: project.name,
                subtitle: project.code,
                onTap: () =>
                    context.push('/projects/${project.id}', extra: project),
              ),
          ],
          if (results.inbox.isNotEmpty) ...[
            _SearchHeading('Инбокс', results.inbox.length),
            for (final task in results.inbox)
              _SearchResult(
                icon: Icons.inbox_outlined,
                title: task.title,
                subtitle: task.displayId,
                onTap: () => showInboxTaskCard(context, task),
              ),
          ],
        ];
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) => entries[index],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _SearchHeading extends StatelessWidget {
  const _SearchHeading(this.text, this.count);
  final String text;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.sm,
    ),
    child: Text(
      '$text · $count',
      style: AppTypography.caption(
        context,
      )?.copyWith(fontWeight: FontWeight.w700),
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
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: AppIconSizes.standard,
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body(
            context,
          )?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: AppIconSizes.standard),
        onTap: onTap,
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });
  final IconData icon;
  final String title, text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              icon,
              size: AppSpacing.touchTarget,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
            )?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          ?action,
        ],
      ),
    ),
  );
}
