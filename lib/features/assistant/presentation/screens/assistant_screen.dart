import '../../../planner/presentation/widgets/ai_day_plan_sheet.dart';
import '../../../planner/domain/repositories/ai_day_plan_repository.dart';
import 'package:jospar/core/localization/app_translations.dart';
import 'package:go_router/go_router.dart';
import '../widgets/assistant_action_cards.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/assistant_web_layout.dart';
import '../../data/services/assistant_attachment_picker.dart';
import '../../domain/entities/assistant_attachment.dart';
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
    this.startKeyboard = false,
    this.initialCommand,
  });
  final bool startVoice;
  final bool startKeyboard;
  final String? initialCommand;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  String _shownConversationId = '';
  final _focus = FocusNode();
  final List<AssistantAttachment> _attachments = [];
  bool _picking = false;
  int _handledResponse = 0;
  final _scroll = ScrollController();
  late final AssistantVoice _voice;
  StreamSubscription<VoiceEvent>? _subscription;
  StreamSubscription<void>? _launchSubscription;
  StreamSubscription<void>? _textLaunchSubscription;
  bool _pendingKeyboardLaunch = false;
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
    _input.addListener(_saveDraft);
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
    if (sl.isRegistered<AssistantLaunchService>()) {
      _textLaunchSubscription = sl<AssistantLaunchService>().textLaunches
          .listen((_) {
            if (!mounted) return;
            _pendingVoiceLaunch = false;
            _acceptResults = false;
            _voiceReply = false;
            unawaited(_voice.stop());
            unawaited(_voice.stopSpeaking());
            _pendingKeyboardLaunch = true;
            _handleInitial(context.read<AssistantCubit>().state);
          });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AssistantCubit>().state;
      _syncDraft(state);
      _handleInitial(state);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _acceptResults = false;
      unawaited(context.read<AssistantCubit>().saveHistory());
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
    _textLaunchSubscription?.cancel();
    unawaited(_voice.stop());
    unawaited(_voice.stopSpeaking());
    _input.removeListener(_saveDraft);
    _focus.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _saveDraft() {
    final cubit = context.read<AssistantCubit>();
    if (_shownConversationId == cubit.state.conversationId) {
      cubit.updateDraft(_input.text);
    }
  }

  void _syncDraft(AssistantState state) {
    if (state.conversationId.isEmpty ||
        _shownConversationId == state.conversationId) {
      return;
    }
    _shownConversationId = state.conversationId;
    _input.value = TextEditingValue(
      text: state.draft,
      selection: TextSelection.collapsed(offset: state.draft.length),
    );
    _attachments.clear();
    _voiceReply = false;
    _handledResponse = state.responseRevision;
  }

  final _assistantScaffold = GlobalKey<ScaffoldState>();

  void _showHistory() {
    FocusScope.of(context).unfocus();
    _assistantScaffold.currentState?.openDrawer();
  }

  Widget _historyDrawer() {
    final cubit = context.read<AssistantCubit>();
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: dark ? colors.canvas : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      width: (MediaQuery.sizeOf(context).width * .86).clamp(0.0, 360.0),
      child: BlocBuilder<AssistantCubit, AssistantState>(
        builder: (context, state) {
          final conversations = state.conversations
              .where((c) => c.messages.isNotEmpty || c.draft.isNotEmpty)
              .toList();
          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, 'История диалогов'),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, 'Закрыть'),
                        onPressed: () =>
                            _assistantScaffold.currentState?.closeDrawer(),
                        icon: Icon(Icons.close, size: 20, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          state.status == AssistantStatus.sending ||
                              state.actionBusy
                          ? null
                          : () {
                              _assistantScaffold.currentState?.closeDrawer();
                              cubit.newConversation();
                            },
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(tr(context, 'Новый чат')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.ink,
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(0, 48),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: colors.border),
                Expanded(
                  child: conversations.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 28,
                                  color: colors.muted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  tr(context, 'Диалогов пока нет'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          itemCount: conversations.length,
                          itemBuilder: (context, i) {
                            final conversation = conversations[i];
                            final date = conversation.updatedAt.toLocal();
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.only(
                                left: 12,
                                right: 4,
                              ),
                              selectedColor: colors.ink,
                              selectedTileColor: colors.accent.withValues(
                                alpha: .07,
                              ),
                              titleTextStyle: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.ink,
                              ),
                              subtitleTextStyle: GoogleFonts.inter(
                                fontSize: 11,
                                color: colors.muted,
                              ),
                              selected: conversation.id == state.conversationId,
                              title: Text(
                                conversation.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                tr(context, "{p0}.{p1}.{p2} · {p3} сообщений", {
                                  'p0': date.day,
                                  'p1': date.month,
                                  'p2': date.year,
                                  'p3': conversation.messages.length,
                                }),
                              ),
                              onTap: () {
                                _assistantScaffold.currentState?.closeDrawer();
                                cubit.openConversation(conversation.id);
                              },
                              trailing: IconButton(
                                tooltip: tr(context, 'Удалить диалог'),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: colors.muted,
                                ),
                                onPressed: () =>
                                    cubit.deleteConversation(conversation.id),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    tr(context, 'На этом устройстве · файлы без содержимого'),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: colors.muted,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _stopResponse() {
    _voiceReply = false;
    _acceptResults = false;
    unawaited(_voice.stop());
    unawaited(_voice.stopSpeaking());
    context.read<AssistantCubit>().stop();
  }

  void _handleInitial(AssistantState state) {
    if (state.status != AssistantStatus.ready) return;
    if (_pendingKeyboardLaunch) {
      _pendingKeyboardLaunch = false;
      _initialHandled = true;
      _focus.requestFocus();
      return;
    }
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
    } else if (widget.startKeyboard) {
      _focus.requestFocus();
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
    if ((text.isEmpty && _attachments.isEmpty) ||
        context.read<AssistantCubit>().state.status ==
            AssistantStatus.sending) {
      return;
    }
    _acceptResults = false;
    await _voice.stop();
    await _voice.stopSpeaking();
    if (!mounted) return;
    _voiceReply = voice;
    final attachments = List<AssistantAttachment>.from(_attachments);
    _input.clear();
    setState(_attachments.clear);
    await context.read<AssistantCubit>().ask(text, attachments: attachments);
  }

  Future<void> _attach() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final attachments = await AssistantAttachmentPicker.pick(
        remaining: 3 - _attachments.length,
      );
      if (mounted) setState(() => _attachments.addAll(attachments));
    } catch (error) {
      if (mounted) {
        setState(
          () => _voiceError = error is AssistantException
              ? error.message
              : 'Не удалось открыть файл.',
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
      _syncDraft(state);
      _handleInitial(state);
      _scrollToBottom();
      if (state.responseRevision > _handledResponse) {
        _handledResponse = state.responseRevision;
        final ids = <String>{};
        for (final tool in state.messages.last.tools) {
          final result = tool.result;
          final action = result?.action;
          if (tool.name == 'open_task' &&
              result != null &&
              !result.hasError &&
              action != null &&
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
        key: _assistantScaffold,
        drawer: _historyDrawer(),
        backgroundColor: AppColors.of(context).canvas,
        body: SafeArea(
          child: Column(
            children: [
              AssistantWebHeader(
                workspaceName:
                    context.read<AssistantCubit>().currentProjectName ??
                    state.workspaceName,
                onHistory:
                    state.workspaceId.isEmpty ||
                        state.status == AssistantStatus.sending ||
                        state.actionBusy
                    ? null
                    : _showHistory,
                onNewConversation:
                    state.workspaceId.isEmpty ||
                        state.status == AssistantStatus.sending ||
                        state.actionBusy
                    ? null
                    : () => context.read<AssistantCubit>().newConversation(),
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
                            if (state.messages[i].draft == null ||
                                state.messages[i].attachments.isNotEmpty ||
                                state.messages[i].attachmentMessage != null)
                              AssistantWebMessage(message: state.messages[i]),
                            AssistantActionCards(
                              key: ValueKey(
                                'actions-${state.conversationId}-$i',
                              ),
                              readOnly: i < state.restoredMessageCount,
                              message: state.messages[i],
                              index: i,
                            ),
                          ],
                        ],
                      ),
              ),
              if (state.status == AssistantStatus.sending)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr(context, 'Готовлю ответ…'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _stopResponse,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: Text(tr(context, 'Остановить')),
                      ),
                    ],
                  ),
                ),
              if (state.stopped)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    tr(
                      context,
                      'Ответ остановлен. Уже выполненные действия сохраняются.',
                    ),
                    style: TextStyle(
                      color: AppColors.of(context).muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (state.historyError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    state.historyError!,
                    style: TextStyle(
                      color: AppColors.of(context).error,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, state.error!),
                          style: TextStyle(color: AppColors.of(context).error),
                        ),
                      ),
                      TextButton(
                        onPressed: context.read<AssistantCubit>().retry,
                        child: Text(tr(context, 'Повторить')),
                      ),
                    ],
                  ),
                ),
              if (_voiceError != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    tr(context, _voiceError!),
                    style: TextStyle(color: AppColors.of(context).error),
                  ),
                ),
              if (_listening || _starting)
                Text(
                  _starting
                      ? tr(context, 'Подключаю микрофон…')
                      : tr(context, 'Слушаю… Скажите вопрос'),
                  style: const TextStyle(color: AppColors.accent),
                ),
              AssistantWebComposer(
                onDayPlan: sl.isRegistered<AiDayPlanRepository>()
                    ? () async {
                        _focus.unfocus();
                        await _voice.stopSpeaking();
                        if (context.mounted) await showAiDayPlan(context);
                      }
                    : null,
                input: _input,
                focus: _focus,
                enabled:
                    state.workspaceId.isNotEmpty &&
                    state.status != AssistantStatus.sending &&
                    !state.actionBusy,
                sending: state.status == AssistantStatus.sending,
                listening: _listening,
                picking: _picking,
                attachments: _attachments,
                onAttach: _attach,
                onRemove: (i) => setState(() => _attachments.removeAt(i)),
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
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              context,
              'В открытом приложении\nВ меню включите «Слушать Ok, Jospar» и произнесите фразу. Сеанс длится до 45 секунд; при уходе из приложения микрофон выключается.',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              context,
              'На iPhone с любого экрана\n1. Откройте Настройки → Универсальный доступ → Голосовые команды (Vocal Shortcuts).\n2. Добавьте действие «Говорить с Jospar» из приложения «Команды».\n3. Назначьте фразу «Ok, Jospar» и повторите её для обучения.\n\nТакже можно вызвать Siri и сказать: «Открыть помощника Jospar». Может понадобиться разблокировать телефон.',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              context,
              'На Android\nВызов внутри приложения работает через микрофон. Запуск с других экранов настраивается через системного помощника телефона.',
            ),
            style: TextStyle(color: AppColors.of(context).muted),
          ),
        ],
      ),
    ),
  ),
);
