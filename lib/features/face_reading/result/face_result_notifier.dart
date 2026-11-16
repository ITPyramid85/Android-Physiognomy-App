import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/server/aura_server_client.dart';
import '../../../data/supabase/reading_repository.dart';
import '../../../domain/entities/landmark_result.dart';
import '../../../domain/entities/reading.dart';

part 'face_result_notifier.g.dart';

class FaceResultState {
  const FaceResultState({
    this.fullText = '',
    this.isStreaming = false,
    this.isSaving = false,
    this.error,
    this.isModelError = false,
    this.reading,
    this.progress = 0,
  });

  final String fullText;
  final bool isStreaming;
  final bool isSaving;
  final String? error;
  final bool isModelError;
  final FaceLandmarkResult? reading;
  final int progress;

  bool get hasContent => fullText.isNotEmpty;

  FaceResultState copyWith({
    String? fullText,
    bool? isStreaming,
    bool? isSaving,
    String? error,
    bool? isModelError,
    FaceLandmarkResult? reading,
    int? progress,
    bool clearError = false,
    bool clearReading = false,
  }) =>
      FaceResultState(
        fullText: fullText ?? this.fullText,
        isStreaming: isStreaming ?? this.isStreaming,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : error ?? this.error,
        isModelError: isModelError ?? (clearError ? false : this.isModelError),
        reading: clearReading ? null : reading ?? this.reading,
        progress: progress ?? this.progress,
      );
}

@riverpod
class FaceResultNotifier extends _$FaceResultNotifier {
  StreamSubscription<AuraEvent>? _sub;
  bool _disposed = false;

  @override
  FaceResultState build() {
    ref.onDispose(() {
      _disposed = true;
      _sub?.cancel();
      _sub = null;
    });
    return const FaceResultState();
  }

  Future<void> analyze({
    required String imagePath,
    required String locale,
  }) async {
    debugPrint('[FaceResultNotifier] analyze locale=$locale');
    _sub?.cancel();
    _sub = null;

    state = state.copyWith(
      isStreaming: true,
      fullText: '',
      progress: 0,
      clearError: true,
      clearReading: true,
    );

    try {
      final client = ref.read(auraServerClientProvider);
      if (_disposed) return;
      final stream = client.analyze(
        imagePath: imagePath,
        kind: 'face',
        locale: locale,
      );

      var buffer = '';
      _sub = stream.listen(
        (event) {
          if (_disposed) return;
          if (event.type == 'progress') {
            final percent = (event.data['percent'] as num?)?.round() ?? state.progress;
            final next = percent < 0 ? 0 : (percent > 100 ? 100 : percent);
            if (next > state.progress) {
              state = state.copyWith(progress: next);
            }
            return;
          }
          if (event.type == 'meta') {
            state = state.copyWith(reading: _readingFromMeta(event.data));
            return;
          }
          if (event.type != 'token') return;
          buffer += event.text;
          if (buffer.length >= 20) {
            state = state.copyWith(fullText: state.fullText + buffer);
            buffer = '';
          }
        },
        onDone: () {
          if (_disposed) return;
          if (buffer.isNotEmpty) {
            state = state.copyWith(fullText: state.fullText + buffer);
          }
          state = state.copyWith(isStreaming: false, progress: 100);
          _sub = null;
        },
        onError: (e) {
          if (_disposed) return;
          debugPrint('[FaceResultNotifier] onError: $e');
          state = state.copyWith(
            isStreaming: false,
            error: _errorCode(e),
            isModelError: _isModelError(e),
          );
          _sub = null;
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[FaceResultNotifier] catch: $e');
      state = state.copyWith(
        isStreaming: false,
        error: _errorCode(e),
        isModelError: _isModelError(e),
      );
    }
  }

  FaceLandmarkResult _readingFromMeta(Map<String, dynamic> data) {
    final raw = data['features'];
    final features = raw is Map
        ? FaceFeatures.fromJson(Map<String, dynamic>.from(raw))
        : const FaceFeatures(
            eyeSpan: 0,
            faceHeight: 0,
            noseRatio: 0,
            mouthWidth: 0,
            symmetry: 0,
            foreheadHeight: 0,
            eyebrowDistance: 0,
          );
    return FaceLandmarkResult(
      landmarks: const [],
      score: (data['score'] as num?)?.toDouble() ?? 1,
      features: features,
      frameWidth: (data['frame_width'] as num?)?.toInt() ?? 0,
      frameHeight: (data['frame_height'] as num?)?.toInt() ?? 0,
    );
  }

  String _errorCode(Object e) {
    if (e is AuraServerException) {
      if (e.code == 'no_face' || e.code == 'no_palm') return e.code;
      return e.message;
    }
    return e.toString();
  }

  bool _isModelError(Object e) {
    if (e is AuraServerException) {
      return e.code == 'model' || e.code == 'server';
    }
    final msg = e.toString();
    return msg.contains('model') || msg.contains('SocketException');
  }

  Future<Reading?> saveReading({
    required String userId,
    required FaceLandmarkResult landmarkResult,
    required String modelUsed,
    required String locale,
    String subjectName = '나',
  }) async {
    if (state.fullText.isEmpty) return null;
    state = state.copyWith(isSaving: true);
    try {
      final reading = await ref.read(readingRepositoryProvider).saveReading(
            userId: userId,
            type: ReadingType.face,
            landmarkResult: landmarkResult,
            resultText: state.fullText,
            modelUsed: modelUsed,
            locale: locale,
            subjectName: subjectName,
          );
      state = state.copyWith(isSaving: false);
      return reading;
    } catch (e) {
      debugPrint('[FaceResultNotifier] saveReading error: $e');
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}
