import 'dart:async';
import 'package:dio/dio.dart';
import '../data/call_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/storage/auth_token_storage.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_theme.dart';
import 'incoming_call_screen.dart';
import 'call_cubit.dart';
import '../data/system_incoming_calls.dart';
import 'system_call_controller.dart';

/// Receives calls throughout the signed-in app, without owning a chat route.
class CallsHost extends StatefulWidget {
  const CallsHost({
    super.key,
    required this.child,
    required this.onOpen,
    required this.onCallPage,
    required this.routeChanges,
  });
  final Widget child;
  final Listenable routeChanges;
  final VoidCallback onOpen;
  final bool Function() onCallPage;
  @override
  State<CallsHost> createState() => _CallsHostState();
}

class _CallsHostState extends State<CallsHost> with WidgetsBindingObserver {
  late final CallEvents _events;
  AudioPlayer? _ringtone;
  String? _ringingId;
  bool _foreground = true, _checking = false, _pendingCheck = false;
  late final SystemCallController _system;
  CallCubit get cubit => sl<CallCubit>();
  @override
  void initState() {
    super.initState();
    _system = SystemCallController(
      cubit,
      SystemIncomingCalls(),
      onOpen: widget.onOpen,
    );
    _system.addListener(_systemChanged);
    WidgetsBinding.instance.addObserver(this);
    authSession.addListener(_authChanged);
    widget.routeChanges.addListener(_routeChanged);
    _events = CallEvents(sl<Dio>(), _check);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startEvents());
    });
  }

  void _systemChanged() {
    if (!mounted) return;
    if (_system.presenting) {
      unawaited(_stopRinging());
    } else {
      unawaited(_syncRinging(cubit.state));
    }
  }

  void _routeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _authChanged() {
    if (authSession.requiresLogin) {
      _events.stop();
      _stopRinging();
      cubit.reset();
    } else if (_foreground) {
      unawaited(_startEvents());
    }
  }

  Future<void> _startEvents() async {
    final token = await sl<AuthTokenStorage>().read();
    if (mounted &&
        _foreground &&
        !authSession.requiresLogin &&
        token != null &&
        token.isNotEmpty) {
      _events.start();
    }
  }

  Future<void> _check() async {
    if (_checking) {
      _pendingCheck = true;
      return;
    }
    if ((!_foreground && !_system.presenting && !cubit.state.busy) ||
        _checking ||
        !mounted) {
      return;
    }
    _checking = true;
    try {
      final token = await sl<AuthTokenStorage>().read();
      if (!mounted) return;
      if (token == null || authSession.requiresLogin) {
        if (cubit.state.busy || cubit.state.incoming != null) {
          await _stopRinging();
          await cubit.reset();
        }
        return;
      }
      await cubit.poll();
      if (mounted && _foreground) await _syncRinging(cubit.state);
    } finally {
      _checking = false;
      if (_pendingCheck && mounted && _foreground) {
        _pendingCheck = false;
        unawaited(_check());
      }
    }
  }

  Future<void> _syncRinging(CallState state) async {
    if (_system.presenting) {
      await _stopRinging();
      return;
    }
    final id = state.incoming?.id;
    if (id == _ringingId) return;
    await _stopRinging();
    if (id == null ||
        !_foreground ||
        !mounted ||
        cubit.state.incoming?.id != id) {
      return;
    }
    _ringingId = id;
    final player = AudioPlayer();
    _ringtone = player;
    try {
      await player.setAsset('assets/audio/incoming_call.wav');
      if (_ringtone != player) return;
      await player.setLoopMode(LoopMode.one);
      unawaited(player.play().catchError((Object _) {}));
      unawaited(HapticFeedback.mediumImpact());
    } catch (_) {
      /* The visible incoming call remains usable if audio is unavailable. */
    }
  }

  Future<void> _stopRinging() async {
    _ringingId = null;
    final player = _ringtone;
    _ringtone = null;
    await player?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_startEvents());
    } else {
      _events.stop();
      _stopRinging();
    }
  }

  @override
  void dispose() {
    _system.removeListener(_systemChanged);
    _system.dispose();
    widget.routeChanges.removeListener(_routeChanged);
    _events.stop();
    authSession.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _stopRinging();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<CallCubit, CallState>(
    bloc: cubit,
    listener: (_, state) => _syncRinging(state),
    builder: (context, state) {
      final incoming = state.incoming;
      return Stack(
        children: [
          widget.child,
          if (incoming != null && !state.busy)
            Positioned.fill(
              child: IncomingCallScreen(
                room: incoming,
                busy: state.controlsBusy,
                error: state.error,
                onDecline: () async {
                  await _stopRinging();
                  await cubit.decline(incoming);
                },
                onAccept: () async {
                  await _stopRinging();
                  await _system.answer(incoming);
                },
              ),
            ),
          if (state.busy && !widget.onCallPage())
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: SafeArea(
                child: Material(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: widget.onOpen,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.call, size: 18, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Вернуться к звонку',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
