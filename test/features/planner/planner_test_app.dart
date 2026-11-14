import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:jospar/features/profile/presentation/cubit/profile_state.dart';

class PlannerTestApp extends StatelessWidget {
  const PlannerTestApp({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      BlocProvider<ProfileCubit>(create: (_) => _ProfileCubit(), child: child);
}

class _ProfileCubit extends Cubit<ProfileState> implements ProfileCubit {
  _ProfileCubit() : super(const ProfileInitial());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
