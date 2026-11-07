import '../../../../core/theme/app_icon_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';

class TaskDetailsSkeleton extends StatefulWidget {
  const TaskDetailsSkeleton({super.key});

  @override
  State<TaskDetailsSkeleton> createState() => _TaskDetailsSkeletonState();
}

class _TaskDetailsSkeletonState extends State<TaskDetailsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    value: 1,
  );
  late final Animation<double> _opacity = _pulse.drive(
    Tween(begin: 0.6, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (reduceMotion) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppColors.accent,
                    value: reduceMotion ? 0.65 : null,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Загрузка задачи…',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ExcludeSemantics(
          child: FadeTransition(
            opacity: _opacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SkeletonBar(fraction: 0.92, height: 20),
                const SizedBox(height: 10),
                const _SkeletonBar(fraction: 0.68, height: 20),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    SizedBox(
                      width: 82,
                      child: _SkeletonBar(height: 24, radius: 8),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: _SkeletonBar(height: 24, radius: 8),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _SkeletonHeading(icon: LucideIcons.alignLeft),
                const SizedBox(height: 12),
                const _SkeletonSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SkeletonBar(fraction: 0.95),
                      SizedBox(height: 9),
                      _SkeletonBar(),
                      SizedBox(height: 9),
                      _SkeletonBar(fraction: 0.74),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SkeletonSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SkeletonBar(fraction: 0.68, height: 8),
                            SizedBox(height: 14),
                            _SkeletonBar(fraction: 0.82, height: 16),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _SkeletonSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SkeletonBar(fraction: 0.48, height: 8),
                            SizedBox(height: 14),
                            _SkeletonBar(fraction: 0.76, height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _SkeletonSurface(
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 28,
                        child: _SkeletonBar(height: 28, radius: 8),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: _SkeletonBar(fraction: 0.65)),
                      SizedBox(width: 12),
                      SizedBox(
                        width: 46,
                        child: _SkeletonBar(height: 24, radius: 8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _SkeletonHeading(icon: LucideIcons.listChecks),
                const SizedBox(height: 14),
                const _SkeletonSurface(
                  child: Column(
                    children: [
                      _SkeletonCheckRow(fraction: 0.88),
                      SizedBox(height: 14),
                      _SkeletonCheckRow(fraction: 0.66),
                      SizedBox(height: 14),
                      _SkeletonCheckRow(fraction: 0.78),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _SkeletonHeading(icon: LucideIcons.messageCircle),
                const SizedBox(height: 16),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: _SkeletonBar(height: 30, radius: 15),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SkeletonBar(fraction: 0.35, height: 9),
                          SizedBox(height: 10),
                          _SkeletonBar(fraction: 0.9),
                          SizedBox(height: 8),
                          _SkeletonBar(fraction: 0.65),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({this.fraction = 1, this.height = 10, this.radius = 4});
  final double fraction, height, radius;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FractionallySizedBox(
      widthFactor: fraction,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: dark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _SkeletonSurface extends StatelessWidget {
  const _SkeletonSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.025),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _SkeletonHeading extends StatelessWidget {
  const _SkeletonHeading({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: AppIconSizes.standard,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16),
      ),
      const SizedBox(width: 10),
      const SizedBox(width: 96, child: _SkeletonBar(height: 12)),
    ],
  );
}

class _SkeletonCheckRow extends StatelessWidget {
  const _SkeletonCheckRow({required this.fraction});
  final double fraction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox.square(
        dimension: 16,
        child: _SkeletonBar(height: 16, radius: 5),
      ),
      const SizedBox(width: 10),
      Expanded(child: _SkeletonBar(fraction: fraction)),
    ],
  );
}
