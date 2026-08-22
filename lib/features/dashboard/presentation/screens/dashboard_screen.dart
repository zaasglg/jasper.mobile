import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/service_locator.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../widgets/dashboard_app_bar.dart';
import '../widgets/dashboard_welcome_header.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => sl<ProfileCubit>()..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: const DashboardAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<ProfileCubit, ProfileState>(
            buildWhen: (previous, current) => current is ProfileLoaded,
            builder: (context, state) {
              final name =
                  state is ProfileLoaded && state.profile.name.isNotEmpty
                  ? state.profile.name
                  : 'Пользователь';
              return DashboardWelcomeHeader(name: name);
            },
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: Text(
                  'Контент дашборда',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9AA0A6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
