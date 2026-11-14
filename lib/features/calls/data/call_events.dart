import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

/// Reconnects the event stream without polling the incoming-calls endpoint.
class CallEvents {
  CallEvents(this.dio, this.onChange);
  final Dio dio;
  final void Function() onChange;
  CancelToken? _token;
  Timer? _retry;
  bool _active = false;
  int _generation = 0;
  int _delay = 1;

  void start() {
    if (_active) return;
    _active = true;
    unawaited(_connect(++_generation));
  }

  Future<void> _connect(int generation) async {
    if (!_active || generation != _generation) return;
    final token = _token = CancelToken();
    try {
      final response = await dio.get<ResponseBody>(
        'realtime/events',
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
      var event = '';
      await for (final line
          in response.data!.stream
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!_active || generation != _generation) return;
        if (line.startsWith('event:')) event = line.substring(6).trim();
        if (line.startsWith('data:')) {
          if (event == 'ready') {
            _delay = 1;
            onChange();
          } else if (event == 'change') {
            final data = jsonDecode(line.substring(5));
            if (data is Map && data['topic'] == 'calls') onChange();
          }
        }
        if (line.isEmpty) event = '';
      }
    } catch (_) {
      // Retry only the event connection; never fall back to incoming polling.
    } finally {
      token.cancel();
      if (_active && generation == _generation) {
        _retry = Timer(Duration(seconds: _delay), () => _connect(generation));
        _delay = (_delay * 2).clamp(1, 30);
      }
    }
  }

  void stop() {
    _active = false;
    _generation++;
    _retry?.cancel();
    _token?.cancel();
  }
}
