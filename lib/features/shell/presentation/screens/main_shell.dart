import 'package:jospar/core/localization/app_translations.dart';
import '../../../workspaces/presentation/widgets/workspace_access_gate.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../../assistant/domain/services/assistant_voice.dart';
import '../../../assistant/domain/utils/wake_phrase.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/service_locator.dart';
import '../../../projects/presentation/cubit/projects_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';
import '../../../profile/presentation/widgets/profile_settings_sections.dart';
import '../widgets/app_bottom_navigation.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';

/// Root shell that hosts the bottom navigation bar and the active tab's
/// content (provided by [child], typically a go_router StatefulNavigationShell).
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTap,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  static void openAssistant(BuildContext context) {
    final shell = context.findAncestorStateOfType<_MainShellState>();
    if (shell != null) {
      unawaited(shell._openAssistant());
    } else {
      context.push('/assistant');
    }
  }

  static Future<void> openProfile(BuildContext context) async {
    final shell = context.findAncestorStateOfType<_MainShellState>();
    await context.push(
      '/profile',
      extra: shell == null
          ? null
          : (
              workspace: shell._workspaceCubit,
              voice: shell._voice == null
                  ? null
                  : VoiceSettingsController(
                      isListening: shell._voiceListeningNotifier,
                      onToggleListening: shell._toggleVoiceWake,
                    ),
            ),
    );
  }

  static const Color _inactive = Color(0xFF9AA0A6);
  static const Color _active = Color(0xFF6D5FE0);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final WorkspaceCubit _workspaceCubit;
  late final ProjectsCubit _projectsCubit;
  AssistantVoice? _voice;
  StreamSubscription<VoiceEvent>? _wakeSubscription;
  bool _wakeArmed = false;
  bool _wakeListening = false;
  bool _openingAssistant = false;
  final ValueNotifier<bool> _voiceListeningNotifier = ValueNotifier(false);

  bool _foreground = true;

  Future<void> _refreshWorkspaces({bool refreshProjects = false}) async {
    final before = _workspaceCubit.state;
    final previousId = before is WorkspaceLoaded ? before.selected?.id : null;
    await _workspaceCubit.load(force: true);
    if (!mounted || !refreshProjects) return;
    final latest = _workspaceCubit.state;
    if (latest is WorkspaceLoaded &&
        latest.selected != null &&
        latest.selected!.id == previousId &&
        _projectsCubit.state.workspaceId == previousId) {
      await _projectsCubit.loadForWorkspaces(
        latest.effectiveSelectedIds,
        primaryId: previousId!,
        refresh: true,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) return;
    unawaited(_refreshWorkspaces(refreshProjects: true));
  }

  Future<void> _openAssistant({bool voice = false, String? command}) async {
    if (_openingAssistant || !mounted) return;
    _openingAssistant = true;
    _wakeArmed = false;
    MainShell.scaffoldKey.currentState?.closeDrawer();
    await _voice?.stop();
    if (!mounted) return;
    final router = GoRouter.of(context);
    final segments =
        router.routerDelegate.currentConfiguration.uri.pathSegments;
    final projectId = segments.length == 2 && segments.first == 'projects'
        ? segments[1]
        : null;
    final location = Uri(
      path: '/assistant',
      queryParameters: {if (voice) 'voice': 'true', 'projectId': ?projectId},
    ).toString();
    await router.push(location, extra: command);
    if (mounted) _openingAssistant = false;
  }

  Future<void> _toggleVoiceWake() async {
    MainShell.scaffoldKey.currentState?.closeDrawer();
    if (_voice == null || !mounted) return;
    if (_wakeArmed) {
      _wakeArmed = false;
      await _voice!.stop();
      return;
    }
    if (widget.currentIndex == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context: context,
          tone: AppSnackBarTone.info,
          content: Text(
            tr(
              context,
              'Откройте Дашборд или Ежедневник для голосового вызова.',
            ),
          ),
        ),
      );
      return;
    }
    _wakeArmed = true;
    await _voice!.listen(VoiceMode.wake);
    if (mounted) _setWakeListening(_voice!.isListening);
  }

  void _setWakeListening(bool value) {
    if (_wakeListening == value) return;
    setState(() => _wakeListening = value);
    _voiceListeningNotifier.value = value;
  }

  void _onWakeEvent(VoiceEvent event) {
    if (!mounted || event.mode != VoiceMode.wake) return;
    if ((event.kind == VoiceEventKind.partial ||
            event.kind == VoiceEventKind.finalResult) &&
        _wakeArmed) {
      final command = commandAfterWakePhrase(event.text);
      if (command != null) {
        _wakeArmed = false;
        unawaited(
          _openAssistant(
            voice: true,
            command:
                event.kind == VoiceEventKind.finalResult && command.isNotEmpty
                ? command
                : null,
          ),
        );
      }
    } else if (event.kind == VoiceEventKind.listening) {
      _setWakeListening(true);
    } else if (event.kind == VoiceEventKind.error ||
        event.kind == VoiceEventKind.stopped) {
      _wakeArmed = false;
      _setWakeListening(false);
      if (event.kind == VoiceEventKind.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar(
            context: context,
            tone: AppSnackBarTone.error,
            content: Text(event.text),
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex == 2 && oldWidget.currentIndex != 2 && _wakeArmed) {
      _wakeArmed = false;
      unawaited(_voice?.stop());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _workspaceCubit = sl<WorkspaceCubit>()..load();
    _projectsCubit = sl<ProjectsCubit>();
    if (sl.isRegistered<AssistantVoice>()) {
      _voice = sl<AssistantVoice>();
      _wakeSubscription = _voice!.events.listen(_onWakeEvent);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeSubscription?.cancel();
    if (_wakeArmed) unawaited(_voice?.stop());
    _workspaceCubit.close();
    _projectsCubit.close();
    _voiceListeningNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      NavigationDestination(
        icon: Icon(
          LucideIcons.layoutDashboard,
          color: MainShell._inactive,
          size: AppIconSizes.standard,
        ),
        selectedIcon: Icon(
          LucideIcons.layoutDashboard,
          color: MainShell._active,
          size: AppIconSizes.standard,
        ),
        label: tr(context, 'Дашборд'),
      ),
      NavigationDestination(
        icon: Icon(
          LucideIcons.columns3,
          color: MainShell._inactive,
          size: AppIconSizes.standard,
        ),
        selectedIcon: Icon(
          LucideIcons.columns3,
          color: MainShell._active,
          size: AppIconSizes.standard,
        ),
        label: tr(context, 'Проекты'),
      ),
      NavigationDestination(
        icon: Icon(
          LucideIcons.messageCircle,
          color: MainShell._inactive,
          size: AppIconSizes.standard,
        ),
        selectedIcon: Icon(
          LucideIcons.messageCircle,
          color: MainShell._active,
          size: AppIconSizes.standard,
        ),
        label: tr(context, 'Мессенджер'),
      ),
      NavigationDestination(
        icon: Icon(
          LucideIcons.inbox,
          color: MainShell._inactive,
          size: AppIconSizes.standard,
        ),
        selectedIcon: Icon(
          LucideIcons.inbox,
          color: MainShell._active,
          size: AppIconSizes.standard,
        ),
        label: tr(context, 'Инбокс'),
      ),
      NavigationDestination(
        icon: Icon(
          LucideIcons.calendarClock,
          color: MainShell._inactive,
          size: AppIconSizes.standard,
        ),
        selectedIcon: Icon(
          LucideIcons.calendarClock,
          color: MainShell._active,
          size: AppIconSizes.standard,
        ),
        label: tr(context, 'Ежедневник'),
      ),
    ];

    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileCubit>(create: (_) => sl<ProfileCubit>()..load()),
        BlocProvider<WorkspaceCubit>.value(value: _workspaceCubit),
        BlocProvider<ProjectsCubit>.value(value: _projectsCubit),
      ],
      child: BlocListener<WorkspaceCubit, WorkspaceState>(
        listenWhen: (previous, current) {
          final previousId = previous is WorkspaceLoaded
              ? previous.selected?.id
              : null;
          final currentId = current is WorkspaceLoaded
              ? current.selected?.id
              : null;
          return current is WorkspaceLoaded &&
              (currentId != previousId ||
                  previous is! WorkspaceLoaded ||
                  !setEquals(
                    previous.effectiveSelectedIds,
                    current.effectiveSelectedIds,
                  ));
        },
        listener: (context, state) {
          final selected = (state as WorkspaceLoaded).selected;
          if (selected != null) {
            context.read<ProjectsCubit>().loadForWorkspaces(
              state.effectiveSelectedIds,
              primaryId: selected.id,
            );
          } else {
            context.read<ProjectsCubit>().clearWorkspace();
          }
        },
        child: Builder(
          builder: (shellContext) => Scaffold(
            key: MainShell.scaffoldKey,
            extendBody: true,
            body: Column(
              children: [
                if (_wakeListening)
                  SafeArea(
                    bottom: false,
                    child: Material(
                      color: MainShell._active.withValues(alpha: 0.08),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.mic,
                          color: MainShell._active,
                          size: AppIconSizes.standard,
                        ),
                        title: Text(tr(context, 'Скажите «Ok, Jospar»')),
                        trailing: IconButton(
                          tooltip: tr(context, 'Остановить'),
                          onPressed: _toggleVoiceWake,
                          icon: const Icon(
                            Icons.close,
                            size: AppIconSizes.standard,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: WorkspaceAccessGate(
                    onOpenMenu: () => MainShell.openProfile(shellContext),
                    child: widget.child,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: BlocBuilder<WorkspaceCubit, WorkspaceState>(
              builder: (context, state) {
                if (state is! WorkspaceLoaded || state.selected == null) {
                  return const SizedBox.shrink();
                }
                return GoRouterState.of(
                      shellContext,
                    ).uri.path.startsWith('/messenger/')
                    ? const SizedBox.shrink()
                    : AppBottomNavigation(
                        selectedIndex: widget.currentIndex.clamp(
                          0,
                          destinations.length - 1,
                        ),
                        onSelected: widget.onTap,
                        destinations: destinations,
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}
