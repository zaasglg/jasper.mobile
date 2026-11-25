import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/daily_quote_repository.dart';
import '../cubit/daily_quote_cubit.dart';

class DashboardDailyQuote extends StatefulWidget {
  const DashboardDailyQuote({
    super.key,
    required this.repository,
    required this.workspaceId,
  });
  final DailyQuoteRepository repository;
  final String workspaceId;
  @override
  State<DashboardDailyQuote> createState() => _DashboardDailyQuoteState();
}

class _DashboardDailyQuoteState extends State<DashboardDailyQuote>
    with WidgetsBindingObserver {
  late DailyQuoteCubit _cubit;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _cubit = DailyQuoteCubit(widget.repository, widget.workspaceId)..load();
  }

  @override
  void didUpdateWidget(DashboardDailyQuote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.repository != widget.repository) {
      _cubit.close();
      _start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _cubit.setActive(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DailyQuoteCubit, DailyQuoteState>(
        bloc: _cubit,
        builder: (context, state) {
          final quote = state.quote;
          if (quote == null) return const SizedBox.shrink();
          final colors = AppColors.of(context);
          return Padding(
            key: const Key('dashboard-daily-quote'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.quote, size: 16, color: colors.muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '«${quote.text}»',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quote.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}
