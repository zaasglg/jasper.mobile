import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_session.dart';
import '../../data/models/channel_info_model.dart';
import '../../domain/repositories/channel_image_repository.dart';

class ChannelInfoState extends Equatable {
  const ChannelInfoState({
    this.info,
    this.loading = true,
    this.saving = false,
    this.error,
  });
  final ChannelInfoModel? info;
  final bool loading, saving;
  final ChannelPhotoError? error;
  @override
  List<Object?> get props => [info, loading, saving, error];
}

class ChannelInfoCubit extends Cubit<ChannelInfoState> {
  ChannelInfoCubit(this.repository, this.picker, this.channelId)
    : super(const ChannelInfoState()) {
    _subscription = repository.channelImageChanges
        .where((e) => e.channelId == channelId)
        .listen((update) {
          if (!isClosed &&
              state.info != null &&
              _session == authSession.generation) {
            emit(
              ChannelInfoState(
                info: state.info!.copyWith(imageUrl: update.imageUrl),
                loading: state.loading,
                saving: state.saving,
                error: state.error,
              ),
            );
          }
        });
  }
  final ChannelImageRepository repository;
  final ChannelPhotoPicker picker;
  final String channelId;
  final int _session = authSession.generation;
  late final StreamSubscription<ChannelImageUpdate> _subscription;
  bool _loading = false;
  bool get _valid => !isClosed && _session == authSession.generation;
  Future<void> load() async {
    if (_loading || state.saving || !_valid) return;
    _loading = true;
    emit(ChannelInfoState(info: state.info));
    try {
      final info = await repository.channelInfo(channelId);
      if (_valid) emit(ChannelInfoState(info: info, loading: false));
    } catch (e) {
      if (_valid) {
        emit(
          ChannelInfoState(
            info: state.info,
            loading: false,
            error: e is ChannelPhotoException ? e.code : ChannelPhotoError.load,
          ),
        );
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> choosePhoto() => _save(remove: false);
  Future<void> removePhoto() => _save(remove: true);
  Future<void> _save({required bool remove}) async {
    if (!_valid ||
        state.loading ||
        state.saving ||
        state.info?.canManageImage != true) {
      return;
    }
    final previous = state.info!;
    emit(ChannelInfoState(info: previous, loading: false, saving: true));
    try {
      final dataUrl = remove ? null : await picker.pick();
      if (!_valid) return;
      if (!remove && dataUrl == null) {
        emit(ChannelInfoState(info: state.info, loading: false));
        return;
      }
      final saved = await repository.setChannelImage(channelId, dataUrl);
      if (_valid) {
        emit(
          ChannelInfoState(
            info: (state.info ?? previous).copyWith(imageUrl: saved),
            loading: false,
          ),
        );
      }
    } catch (e) {
      if (!_valid) return;
      final error = e is ChannelPhotoException
          ? e.code
          : ChannelPhotoError.save;
      emit(
        ChannelInfoState(
          info: (state.info ?? previous).copyWith(
            canManageImage: error == ChannelPhotoError.forbidden ? false : null,
          ),
          loading: false,
          error: error,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
