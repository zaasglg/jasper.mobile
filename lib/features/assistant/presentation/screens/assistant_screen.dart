import 'package:go_router/go_router.dart';
import '../widgets/assistant_action_cards.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/assistant_web_layout.dart';
import '../../data/services/assistant_image_picker.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../../../../core/voice/assistant_launch_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/services/assistant_voice.dart';
import '../cubit/assistant_cubit.dart';
import '../cubit/assistant_state.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    this.startVoice = false,
    this.initialCommand,
  });
  final bool startVoice;
  final String? initialCommand;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final List<String> _images = [];
  bool _picking = false;
  int _handledResponse = 0;
  final _scroll = ScrollController();
  late final AssistantVoice _voice;
  StreamSubscription<VoiceEvent>? _subscription;
  StreamSubscription<void>? _launchSubscription;
  bool _pendingVoiceLaunch = false;
  bool _listening = false;
  bool _starting = false;
  bool _voiceReply = false;
  bool _initialHandled = false;
  bool _acceptResults = false;
  String? _voiceError;
  String _dictationPrefix = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = sl<AssistantVoice>();
    _subscription = _voice.events.listen(_onVoice);
    if (sl.isRegistered<AssistantLaunchService>()) {
      _launchSubscription = sl<AssistantLaunchService>().repeatedLaunches
          .listen((_) {
            if (!mounted) return;
            if (context.read<AssistantCubit>().state.status ==
                AssistantStatus.ready) {
              _startVoice();
            } else {
              _pendingVoiceLaunch = true;
            }
          });
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleInitial(context.read<AssistantCubit>().state),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _acceptResults = false;
      unawaited(_voice.stop());
      unawaited(_voice.stopSpeaking());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _acceptResults = false;
    _subscription?.cancel();
    _launchSubscription?.cancel();
    unawaited(_voice.stop());
    unawaited(_voice.stopSpeaking());
    _focus.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _handleInitial(AssistantState state) {
    if (state.status != AssistantStatus.ready) return;
    if (_pendingVoiceLaunch) {
      _pendingVoiceLaunch = false;
      _voiceReply = false;
      _initialHandled = true;
      _startVoice();
      return;
    }
    if (_initialHandled) return;
    _initialHandled = true;
    final command = widget.initialCommand?.trim() ?? '';
    if (command.isNotEmpty) {
      _voiceReply = true;
      context.read<AssistantCubit>().ask(command);
    } else if (widget.startVoice) {
      _startVoice();
    }
  }

  void _onVoice(VoiceEvent event) {
    if (!mounted || event.mode != VoiceMode.dictation) return;
    if (event.kind == VoiceEventKind.partial ||
        event.kind == VoiceEventKind.finalResult) {
      if (!_acceptResults) return;
      _input.text = '$_dictationPrefix${event.text}';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      if (event.kind == VoiceEventKind.finalResult &&
          event.text.trim().isNotEmpty) {
        _acceptResults = false;
        _send(voice: true);
      }
    } else if (event.kind == VoiceEventKind.listening) {
      setState(() {
        _listening = true;
        _starting = false;
      });
    } else {
      setState(() {
        _listening = false;
        _starting = false;
        if (event.kind == VoiceEventKind.error) {
          _voiceError = event.text;
          _acceptResults = false;
        }
      });
    }
  }

  Future<void> _startVoice() async {
    final state = context.read<AssistantCubit>().state;
    if (_starting ||
        state.status == AssistantStatus.sending ||
        state.workspaceId.isEmpty) {
      return;
    }
    _dictationPrefix = _input.text.trim().isEmpty
        ? ''
        : '${_input.text.trim()} ';
    _acceptResults = true;
    setState(() {
      _starting = true;
      _voiceError = null;
    });
    await _voice.listen(VoiceMode.dictation);
    if (mounted) {
      setState(() {
        _starting = false;
        _listening = _voice.isListening;
      });
    }
  }

  Future<void> _send({bool voice = false}) async {
    final text = _input.text.trim();
    if ((text.isEmpty && _images.isEmpty) ||
        context.read<AssistantCubit>().state.status ==
            AssistantStatus.sending) {
      return;
    }
    _acceptResults = false;
    await _voice.stop();
    await _voice.stopSpeaking();
    if (!mounted) return;
    _voiceReply = voice;
    final images = List<String>.from(_images);
    _input.clear();
    setState(_images.clear);
    await context.read<AssistantCubit>().ask(text, images: images);
  }

  Future<void> _attach() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final images = await AssistantImagePicker.pick(
        remaining: 3 - _images.length,
      );
      if (mounted) setState(() => _images.addAll(images));
    } catch (error) {
      if (mounted) {
        setState(
          () => _voiceError = error is AssistantException
              ? error.message
              : 'Не удалось открыть изображение.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<AssistantCubit, AssistantState>(
    listener: (_, state) {
      _handleInitial(state);
      _scrollToBottom();
      if (state.responseRevision > _handledResponse) {
        _handledResponse = state.responseRevision;
        final ids = <String>{};
        for (final tool in state.messages.last.tools) {
          final result = tool['result'];
          final action = result is Map ? result['action'] : null;
          if (tool['name'] == 'open_task' &&
              result is Map &&
              !result.containsKey('error') &&
              action is Map &&
              action['type'] == 'open_task' &&
              action['workspaceId'] == state.workspaceId &&
              action['taskId'] is String &&
              (action['taskId'] as String).trim().isNotEmpty) {
            ids.add(action['taskId'] as String);
          }
        }
        if (ids.length == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.push('/tasks/${Uri.encodeComponent(ids.single)}');
            }
          });
        }
      }
      if (state.status == AssistantStatus.ready &&
          _voiceReply &&
          state.messages.lastOrNull?.role == 'assistant') {
        _voiceReply = false;
        unawaited(_voice.speak(state.messages.last.content));
      }
    },
    builder: (context, state) => Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              AssistantWebHeader(
                workspaceName:
                    context.read<AssistantCubit>().currentProjectName ??
                    state.workspaceName,
                onStopVoice: () => _voice.stopSpeaking(),
                onVoiceHelp: () => showVoiceLaunchHelp(context),
              ),
              Expanded(
                child: state.status == AssistantStatus.loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        children: [
                          if (state.messages.isEmpty)
                            AssistantWebWelcome(
                              hasWorkspace: state.workspaceId.isNotEmpty,
                              onSuggestion: (prompt) {
                                _input.text = prompt;
                                _input.selection = TextSelection.collapsed(
                                  offset: prompt.length,
                                );
                                _focus.requestFocus();
                              },
                            ),
                          for (var i = 0; i < state.messages.length; i++) ...[
                            if (state.messages[i].draft == null)
                              AssistantWebMessage(message: state.messages[i]),
                            AssistantActionCards(
                              key: ValueKey('actions-$i'),
                              message: state.messages[i],
                              index: i,
                            ),
                          ],
                        ],
                      ),
              ),
              if (state.status == AssistantStatus.sending)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Работаю с запросом',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                      TextButton(
                        onPressed: context.read<AssistantCubit>().retry,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              if (_voiceError != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _voiceError!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (_listening || _starting)
                Text(
                  _starting ? 'Подключаю микрофон…' : 'Слушаю… Скажите вопрос',
                  style: const TextStyle(color: AppColors.accent),
                ),
              AssistantWebComposer(
                input: _input,
                focus: _focus,
                enabled:
                    state.workspaceId.isNotEmpty &&
                    state.status != AssistantStatus.sending,
                sending: state.status == AssistantStatus.sending,
                listening: _listening,
                picking: _picking,
                images: _images,
                onAttach: _attach,
                onRemove: (i) => setState(() => _images.removeAt(i)),
                onSend: () => _send(),
                onVoice: () {
                  if (_listening) {
                    _acceptResults = false;
                    _voice.stop();
                  } else if (!_starting) {
                    _startVoice();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showVoiceLaunchHelp(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '«Ok, Jospar»',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'В открытом приложении\nВ меню включите «Слушать Ok, Jospar» и произнесите фразу. Сеанс длится до 45 секунд; при уходе из приложения микрофон выключается.',
          ),
          const SizedBox(height: 16),
          const Text(
            'На iPhone с любого экрана\n1. Откройте Настройки → Универсальный доступ → Голосовые команды (Vocal Shortcuts).\n2. Добавьте действие «Говорить с Jospar» из приложения «Команды».\n3. Назначьте фразу «Ok, Jospar» и повторите её для обучения.\n\nТакже можно вызвать Siri и сказать: «Открыть помощника Jospar». Может понадобиться разблокировать телефон.',
          ),
          const SizedBox(height: 16),
          const Text(
            'На Android\nВызов внутри приложения работает через микрофон. Запуск с других экранов настраивается через системного помощника телефона.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  ),
);
