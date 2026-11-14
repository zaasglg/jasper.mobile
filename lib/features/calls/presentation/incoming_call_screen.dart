import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_ui_tokens.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../data/call_models.dart';

abstract final class IncomingCallStyle {
  static const background = Color(0xff202c33);
  static const accept = Color(0xff25d366);
  static const decline = Color(0xffff3b30);
  static const avatarSize = 160.0;
  static const actionSize = 72.0;
}

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({
    super.key,
    required this.room,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
    this.error,
  });

  final CallRoom room;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Material(
      color: IncomingCallStyle.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.call_outlined,
                    color: Colors.white,
                    size: AppSpacing.mdLg,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'ЗВОНОК JOSPAR',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                room.callerName.isEmpty ? 'Входящий звонок' : room.callerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                room.video ? 'Входящий видеозвонок' : 'Входящий аудиозвонок',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: UserAvatar(
                      size: IncomingCallStyle.avatarSize,
                      userId: room.callerId,
                      name: room.callerName,
                      avatarUrl: room.callerAvatar,
                    ),
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _IncomingAction(
                      actionKey: const Key('incoming_decline'),
                      label: 'Отклонить',
                      icon: Icons.call_end,
                      color: IncomingCallStyle.decline,
                      onPressed: busy ? null : onDecline,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: _IncomingAction(
                      actionKey: const Key('incoming_accept'),
                      label: 'Принять',
                      icon: room.video ? Icons.videocam : Icons.call,
                      color: IncomingCallStyle.accept,
                      onPressed: busy ? null : onAccept,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    ),
  );
}

class _IncomingAction extends StatelessWidget {
  const _IncomingAction({
    required this.actionKey,
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });
  final Key actionKey;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filled(
        key: actionKey,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: color.withValues(alpha: .4),
          disabledForegroundColor: Colors.white70,
          fixedSize: const Size.square(IncomingCallStyle.actionSize),
        ),
        icon: Icon(icon, size: AppSpacing.xl, semanticLabel: label),
      ),
      const SizedBox(height: AppSpacing.smMd),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    ],
  );
}
