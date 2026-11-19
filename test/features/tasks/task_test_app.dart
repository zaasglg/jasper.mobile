import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jospar/core/theme/app_theme.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_state.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_cubit.dart';
import 'package:jospar/features/workspaces/presentation/cubit/workspace_state.dart';

class TaskTestApp extends StatelessWidget {
  const TaskTestApp({super.key, required this.home});
  final Widget home;
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<ProfileCubit>(create: (_) => _Profile()),
      BlocProvider<WorkspaceCubit>(create: (_) => _Workspace()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: home),
  );
}

class _Profile extends Cubit<ProfileState> implements ProfileCubit {
  _Profile() : super(const ProfileInitial());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Workspace extends Cubit<WorkspaceState> implements WorkspaceCubit {
  _Workspace() : super(const WorkspaceInitial());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
