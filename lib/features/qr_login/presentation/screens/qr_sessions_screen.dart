import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/entities/qr_session_model.dart';
import '../cubit/qr_sessions_cubit.dart';
import '../cubit/qr_sessions_state.dart';

class QrSessionsScreen extends StatelessWidget {
  const QrSessionsScreen({
    super.key,
    required this.accountName,
    required this.email,
  });

  final String accountName;
  final String email;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : const Color(0xFFF7F7FB),
    appBar: AppBar(
      backgroundColor: AppColors.of(context).canvas,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        tr(context, 'Активные сеансы'),
        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ),
    body: BlocBuilder<QrSessionsCubit, QrSessionsState>(
      builder: (context, state) => switch (state) {
        QrSessionsLoading() => const Center(child: CircularProgressIndicator()),
        QrSessionsFailure failure => _Failure(
          message: failure.message,
          onRetry: context.read<QrSessionsCubit>().load,
        ),
        QrSessionsLoaded loaded => RefreshIndicator(
          onRefresh: context.read<QrSessionsCubit>().load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              _LinkDeviceCard(
                onTap: () => context.push(
                  '/qr-login',
                  extra: (name: accountName, email: email),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                tr(context, 'Подключённые устройства'),
                style: GoogleFonts.inter(
                  color: const Color(0xFF858297),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (loaded.sessions.isEmpty)
                const _EmptySessions()
              else
                ...loaded.sessions.map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SessionTile(
                      session: session,
                      busy: loaded.revokingId == session.id,
                      onTap: () => _confirmRevoke(context, session),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                tr(
                  context,
                  'Если вы не узнаёте устройство, завершите его сеанс.',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF858297),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      },
    ),
  );

  Future<void> _confirmRevoke(
    BuildContext context,
    QrSessionModel session,
  ) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.of(context).canvas,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.monitorOff,
                size: 42,
                color: Color(0xFFD64545),
              ),
              const SizedBox(height: 14),
              Text(
                tr(context, 'Выйти на этом устройстве?'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                session.deviceInfo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF858297)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD64545),
                  ),
                  child: Text(tr(context, 'Завершить сеанс')),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(tr(context, 'Отмена')),
              ),
            ],
          ),
        ),
      ),
    );
    if (accepted == true && context.mounted) {
      await context.read<QrSessionsCubit>().revoke(session.id);
    }
  }
}

class _LinkDeviceCard extends StatelessWidget {
  const _LinkDeviceCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF6D5FE0),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      key: const Key('qr_sessions_link_device'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x26FFFFFF),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(13),
                child: Icon(LucideIcons.scanQrCode, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Подключить устройство'),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr(context, 'Отсканируйте QR-код на компьютере'),
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.busy,
    required this.onTap,
  });

  final QrSessionModel session;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.of(context).canvas,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: Key('qr_session_${session.id}'),
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF0EDFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.monitor, color: Color(0xFF6D5FE0)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.deviceInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_activityText(session.lastActiveAt)} · ${session.ipAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF858297),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                LucideIcons.logOut,
                size: 20,
                color: Color(0xFFD64545),
              ),
          ],
        ),
      ),
    ),
  );
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.of(context).canvas,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const Icon(LucideIcons.monitor, color: Color(0xFFAAA6B8), size: 34),
        const SizedBox(height: 12),
        Text(
          tr(context, 'Нет активных сеансов'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          tr(context, 'Подключённые через QR устройства появятся здесь.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF858297), fontSize: 13),
        ),
      ],
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.wifiOff, size: 38, color: Color(0xFF858297)),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRetry,
            child: Text(tr(context, 'Повторить')),
          ),
        ],
      ),
    ),
  );
}

String _activityText(DateTime date) {
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.inMinutes < 2) return 'Активен сейчас';
  if (difference.inMinutes < 60) return '${difference.inMinutes} мин. назад';
  if (difference.inHours < 24) return '${difference.inHours} ч. назад';
  return '${date.toLocal().day.toString().padLeft(2, '0')}.${date.toLocal().month.toString().padLeft(2, '0')}.${date.toLocal().year}';
}
