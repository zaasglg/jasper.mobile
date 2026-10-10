import '../../../../core/voice/assistant_launch_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
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
    if (text.isEmpty ||
        context.read<AssistantCubit>().state.status ==
            AssistantStatus.sending) {
      return;
    }
    _acceptResults = false;
    await _voice.stop();
    await _voice.stopSpeaking();
    if (!mounted) return;
    _voiceReply = voice;
    _input.clear();
    await context.read<AssistantCubit>().ask(text);
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
      if (state.status == AssistantStatus.ready &&
          _voiceReply &&
          state.messages.lastOrNull?.role == 'assistant') {
        _voiceReply = false;
        unawaited(_voice.speak(state.messages.last.content));
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        title: Text(
          'Jospar AI',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Остановить озвучивание',
            onPressed: _voice.stopSpeaking,
            icon: const Icon(Icons.volume_off_outlined),
          ),
          IconButton(
            tooltip: 'Голосовой вызов',
            onPressed: () => showVoiceLaunchHelp(context),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.workspaceName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.workspaceName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: state.status == AssistantStatus.loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : state.messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 40,
                              color: AppColors.accent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Чем помочь?',
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Спросите о задачах и проектах — голосом или текстом.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.messages.length,
                      itemBuilder: (_, index) {
                        final message = state.messages[index];
                        final user = message.role == 'user';
                        return Align(
                          alignment: user
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.86,
                            ),
                            decoration: BoxDecoration(
                              color: user
                                  ? AppColors.accent.withValues(alpha: 0.1)
                                  : AppColors.subtleSurface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SelectableText(
                              message.content,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
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
                    Text('Думаю…', style: TextStyle(color: AppColors.muted)),
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    key: const Key('assistant-microphone'),
                    tooltip: _listening
                        ? 'Остановить запись'
                        : 'Задать вопрос голосом',
                    onPressed:
                        state.workspaceId.isEmpty ||
                            state.status == AssistantStatus.sending ||
                            _starting
                        ? null
                        : _listening
                        ? () {
                            _acceptResults = false;
                            _voice.stop();
                          }
                        : _startVoice,
                    icon: Icon(
                      _listening
                          ? Icons.stop_circle_outlined
                          : Icons.mic_none_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('assistant-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      enabled:
                          state.workspaceId.isNotEmpty &&
                          state.status != AssistantStatus.sending,
                      decoration: const InputDecoration(
                        hintText: 'Спросите Jospar',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('assistant-send'),
                    tooltip: 'Отправить',
                    onPressed:
                        state.workspaceId.isEmpty ||
                            state.status == AssistantStatus.sending
                        ? null
                        : () => _send(),
                    icon: const Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
