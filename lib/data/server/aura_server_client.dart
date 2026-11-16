import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';

class ServerHealth {
  const ServerHealth({
    required this.ok,
    required this.model,
    required this.backend,
    this.error,
  });

  final bool ok;
  final String model;
  final String backend;
  final String? error;

  factory ServerHealth.fromJson(Map<String, dynamic> json) {
    return ServerHealth(
      ok: json['ok'] == true,
      model: json['model']?.toString() ?? '',
      backend: json['backend']?.toString() ?? 'cpu',
      error: json['error']?.toString(),
    );
  }
}

class AuraServerException implements Exception {
  AuraServerException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message.isEmpty ? code : message;
}

class AuraEvent {
  const AuraEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;

  String? get code => data['code']?.toString();
  String get text => data['text']?.toString() ?? '';
}

final auraServerClientProvider = Provider<AuraServerClient>((ref) {
  final client = AuraServerClient();
  ref.onDispose(client.close);
  return client;
});

final serverHealthProvider = FutureProvider<ServerHealth>((ref) {
  return ref.watch(auraServerClientProvider).health();
});

class AuraServerClient {
  AuraServerClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? resolveAuraServerUrl(),
              connectTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(minutes: 2),
              receiveTimeout: const Duration(minutes: 10),
            ));

  final Dio _dio;

  Future<ServerHealth> health() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    return ServerHealth.fromJson(response.data ?? const {});
  }

  /// [kind] 는 `face`(얼굴) 또는 `hand`(손). 업로드와 분석 진행률은 progress 이벤트다.
  Stream<AuraEvent> analyze({
    required String imagePath,
    required String kind,
    required String locale,
  }) {
    return _request((cancel, emit) {
      return _dio.post<ResponseBody>(
        '/v1/analyze',
        data: FormData.fromMap({
          'image': MultipartFile.fromFileSync(imagePath),
          'kind': kind,
          'locale': locale,
        }),
        cancelToken: cancel,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          final percent = (sent / total * 8).round().clamp(1, 8);
          emit(AuraEvent('progress', {'percent': percent, 'stage': 'upload'}));
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {Headers.acceptHeader: 'text/event-stream'},
        ),
      );
    });
  }

  Stream<String> chat({
    required String locale,
    required String analysisType,
    required String contextSummary,
    required Map<String, dynamic> features,
    required List<Map<String, String>> history,
    required String message,
  }) async* {
    await for (final event in _postSse('/v1/chat', {
      'locale': locale,
      'analysis_type': analysisType,
      'context_summary': contextSummary,
      'features': features,
      'history': history,
      'message': message,
    })) {
      if (event.type == 'token' && event.text.isNotEmpty) {
        yield event.text;
      } else if (event.type == 'error') {
        throw AuraServerException(event.code ?? 'model', event.text.isEmpty
            ? (event.data['message']?.toString() ?? 'chat failed')
            : event.data['message']?.toString() ?? event.text);
      }
    }
  }

  Stream<AuraEvent> _postSse(String path, Map<String, dynamic> body) {
    return _request((cancel, _) {
      return _dio.post<ResponseBody>(
        path,
        data: body,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: {Headers.acceptHeader: 'text/event-stream'},
        ),
      );
    });
  }

  Stream<AuraEvent> _request(
    Future<Response<ResponseBody>> Function(
      CancelToken cancel,
      void Function(AuraEvent event) emit,
    ) send,
  ) {
    final cancel = CancelToken();
    late StreamController<AuraEvent> controller;
    controller = StreamController<AuraEvent>(
      onCancel: () {
        if (!cancel.isCancelled) cancel.cancel();
      },
    );

    () async {
      try {
        final response = await send(cancel, (event) {
          if (!controller.isClosed) controller.add(event);
        });
        final byteStream = response.data?.stream;
        if (byteStream == null) {
          throw AuraServerException('server', 'empty response');
        }
        await for (final event in _parseSse(byteStream)) {
          if (controller.isClosed) return;
          if (event.type == 'error') {
            controller.addError(AuraServerException(
              event.code ?? 'model',
              event.data['message']?.toString() ?? 'request failed',
            ));
            return;
          }
          controller.add(event);
          if (event.type == 'done') return;
        }
      } on DioException catch (e) {
        if (CancelToken.isCancel(e) || controller.isClosed) return;
        final message = e.message ?? e.toString();
        controller.addError(AuraServerException('server', message));
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }();

    return controller.stream;
  }

  Stream<AuraEvent> _parseSse(Stream<List<int>> bytes) async* {
    final buffer = StringBuffer();
    await for (final chunk in bytes.cast<List<int>>().transform(utf8.decoder)) {
      buffer.write(chunk);
      var text = buffer.toString().replaceAll('\r\n', '\n');
      buffer.clear();
      while (true) {
        final split = text.indexOf('\n\n');
        if (split < 0) {
          buffer.write(text);
          break;
        }
        final raw = text.substring(0, split);
        text = text.substring(split + 2);
        final event = _decodeEvent(raw);
        if (event != null) yield event;
      }
    }
  }

  AuraEvent? _decodeEvent(String raw) {
    var type = 'message';
    final data = StringBuffer();
    for (final line in raw.split('\n')) {
      if (line.startsWith('event:')) {
        type = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.write(line.substring(5).trim());
      }
    }
    if (data.isEmpty) return null;
    final decoded = jsonDecode(data.toString());
    final map = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'text': decoded.toString()};
    return AuraEvent(type, map);
  }

  void close() {
    _dio.close(force: true);
  }
}

String resolveAuraServerUrl() {
  if (AppConst.serverUrlOverride.isNotEmpty) return AppConst.serverUrlOverride;
  if (!kIsWeb && Platform.isAndroid) return 'http://167.114.172.44:8787';
  return 'http://167.114.172.44:8787';
}
