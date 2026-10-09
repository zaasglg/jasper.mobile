import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DashboardWelcomeHeader extends StatelessWidget {
  const DashboardWelcomeHeader({
    super.key,
    this.name = 'Пользователь',
    this.onEdit,
    this.onCreate,
  });

  final String name;
  final VoidCallback? onEdit;
  final VoidCallback? onCreate;

  static const Color _title = Color(0xFF16181D);
  static const Color _subtitle = Color(0xFF8A9099);
  static const Color _accent = Color(0xFF6D5FE0);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F6F8), Color(0xFFEEF0F7)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 12,
            right: 48,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Приветствую,',
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _subtitle,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: GoogleFonts.manrope(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: _title,
                              height: 1.15,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ActionCluster(onEdit: onEdit, onCreate: onCreate),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCluster extends StatelessWidget {
  const _ActionCluster({this.onEdit, this.onCreate});

  final VoidCallback? onEdit;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E9EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            onTap: onEdit,
            background: Colors.white,
            child: const Icon(
              LucideIcons.pencil,
              size: 17,
              color: Color(0xFF4A4F58),
            ),
          ),
          const SizedBox(width: 4),
          _ActionButton(
            onTap: onCreate,
            background: DashboardWelcomeHeader._accent,
            elevated: true,
            child: const Icon(LucideIcons.plus, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.background,
    required this.child,
    this.onTap,
    this.elevated = false,
  });

  final Color background;
  final Widget child;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: DashboardWelcomeHeader._accent.withValues(
                        alpha: 0.28,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
