import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../workspaces/presentation/cubit/workspace_cubit.dart';
import '../../../workspaces/presentation/cubit/workspace_state.dart';

/// Refresh only the visible messenger route while the application is resumed.
/// Kept shell branches must not mark hidden conversations as read.
mixin MessengerRefreshLifecycle<T extends StatefulWidget> on State<T> {
  AppLifecycleListener? _lifecycle;
  GoRouter? _refreshRouter;
  StreamSubscription<WorkspaceState>? _workspaceSubscription;
  bool _resumed = true, _staleWorkspace = false;
  String? _workspace;
  String get messengerRefreshPath;
  bool get isMessengerConversation => false;
  void setMessengerRefresh(bool active);
  void invalidateMessenger();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lifecycle != null) return;
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _resumed = state == AppLifecycleState.resumed;
        _refreshVisibility();
      },
    );
    _refreshRouter = GoRouter.maybeOf(context);
    _refreshRouter?.routerDelegate.addListener(_refreshVisibility);
    authSession.addListener(_authChanged);
    try {
      final cubit = context.read<WorkspaceCubit>();
      final state = cubit.state;
      _workspace = state is WorkspaceLoaded ? state.selected?.id : null;
      _workspaceSubscription = cubit.stream.listen((state) {
        if (state is! WorkspaceLoaded) return;
        final next = state.selected?.id;
        if (_workspace == next) return;
        final hadWorkspace = _workspace != null;
        _workspace = next;
        setMessengerRefresh(false);
        if (!isMessengerConversation || hadWorkspace) invalidateMessenger();
        if (isMessengerConversation && hadWorkspace) {
          _staleWorkspace = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _refreshRouter?.routeInformationProvider.value.uri.path ==
                    messengerRefreshPath) {
              _refreshRouter?.go('/messenger');
            }
          });
        }
        _refreshVisibility();
      });
    } on ProviderNotFoundException {
      // Isolated screens/tests may not have the application workspace shell.
    }
    _refreshVisibility();
  }

  void _authChanged() {
    if (authSession.requiresLogin) invalidateMessenger();
    _refreshVisibility();
  }

  void _refreshVisibility() {
    if (!mounted) return;
    final path = _refreshRouter?.routeInformationProvider.value.uri.path;
    final visible = path == null
        ? ModalRoute.of(context)?.isCurrent ?? true
        : path == messengerRefreshPath;
    if (_staleWorkspace && visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _staleWorkspace &&
            _refreshRouter?.routeInformationProvider.value.uri.path ==
                messengerRefreshPath) {
          _refreshRouter?.go('/messenger');
        }
      });
    }
    setMessengerRefresh(
      _resumed && visible && !_staleWorkspace && !authSession.requiresLogin,
    );
  }

  @override
  void dispose() {
    _refreshRouter?.routerDelegate.removeListener(_refreshVisibility);
    authSession.removeListener(_authChanged);
    unawaited(_workspaceSubscription?.cancel());
    _lifecycle?.dispose();
    setMessengerRefresh(false);
    super.dispose();
  }
}
