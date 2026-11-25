import 'package:jospar/core/localization/app_translations.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../widgets/conversation_menu.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_icon_sizes.dart';
import '../../data/models/chat_conversation_model.dart';
import '../../domain/repositories/chat_repository.dart';

class MessengerSettingsState extends Equatable {
  const MessengerSettingsState({
    this.loading = true,
    this.busy = false,
    this.chats = const [],
    this.error,
  });
  final bool loading, busy;
  final List<ChatConversationModel> chats;
  final String? error;
  MessengerSettingsState copyWith({
    bool? loading,
    bool? busy,
    List<ChatConversationModel>? chats,
    String? error,
  }) => MessengerSettingsState(
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    chats: chats ?? this.chats,
    error: error,
  );
  @override
  List<Object?> get props => [loading, busy, chats, error];
}

class MessengerSettingsCubit extends Cubit<MessengerSettingsState> {
  MessengerSettingsCubit(this.repository)
    : super(const MessengerSettingsState());
  final ChatRepository repository;
  ChatActionsRepository get actions => repository as ChatActionsRepository;
  Future<void> load() async {
    emit(state.copyWith(loading: true));
    try {
      final chats = await repository.getConversations();
      if (!isClosed) emit(state.copyWith(chats: chats, loading: false));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<bool> run(Future<void> Function() action) async {
    if (state.busy) return false;
    emit(state.copyWith(busy: true));
    try {
      await action();
      if (!isClosed) {
        await load();
        emit(state.copyWith(busy: false, error: state.error));
      }
      return true;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }
}

class MessengerSettingsScreen extends StatelessWidget {
  const MessengerSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MessengerSettingsCubit(sl<ChatRepository>())..load(),
    child: const _SettingsBody(),
  );
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();
  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MessengerSettingsCubit, MessengerSettingsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              appSnackBar(
                context: context,
                tone: AppSnackBarTone.error,
                content: Text(tr(context, state.error!)),
              ),
            );
          }
        },
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(tr(context, 'Настройки мессенджера'))),
          body: RefreshIndicator(
            onRefresh: context.read<MessengerSettingsCubit>().load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (state.loading || state.busy)
                  const LinearProgressIndicator(minHeight: 2),
                Text(
                  tr(context, 'Каналы'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                if (state.error != null)
                  TextButton(
                    onPressed: context.read<MessengerSettingsCubit>().load,
                    child: Text(tr(context, 'Повторить загрузку')),
                  ),
                for (final channel in state.chats.where((e) => e.isChannel))
                  ListTile(
                    leading: const Icon(
                      LucideIcons.hash,
                      size: AppIconSizes.standard,
                    ),
                    title: Text(channel.title),
                    trailing: ConversationMenuButton(
                      conversation: channel,
                      repository: context
                          .read<MessengerSettingsCubit>()
                          .repository,
                      chats: state.chats,
                      onChanged: context.read<MessengerSettingsCubit>().load,
                    ),
                  ),
                if (!state.loading && state.chats.every((e) => !e.isChannel))
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(tr(context, 'Нет доступных каналов')),
                  ),
              ],
            ),
          ),
        ),
      );
}
