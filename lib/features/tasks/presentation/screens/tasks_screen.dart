import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).canvas,
        elevation: 0,
        title: Text(
          tr(context, 'Проекты'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: Center(child: Text(tr(context, 'Проекты'))),
    );
  }
}
