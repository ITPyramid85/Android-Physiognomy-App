import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 진단 로그를 공용 다운로드 폴더의 `aura-log.txt` 에 남긴다.
///
/// 기록은 네이티브에서 fsync 까지 끝난 뒤에 반환된다. 강제 종료 직전에
/// await 한 줄은 파일에 남아 있다.
class AppLog {
  AppLog._();

  static const _channel = MethodChannel('kr.co.taoist.gwansang/log');

  /// 마지막으로 확인한 로그 파일 위치. 예: Download/aura-log.txt
  static String? path;

  static DebugPrintCallback? _previousDebugPrint;
  static var _insideHook = false;

  /// 기존 debugPrint 출력도 같은 로그 파일로 보낸다.
  static void captureDebugPrint() {
    if (_previousDebugPrint != null) return;
    _previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      _previousDebugPrint!(message, wrapWidth: wrapWidth);
      if (_insideHook || message == null || message.isEmpty) return;
      unawaited(_append('debug', message));
    };
  }

  static Future<void> write(String tag, String message) => _append(tag, message);

  static Future<void> _append(String tag, String message) async {
    final line = '${DateTime.now().toIso8601String()} [$tag] $message\n';
    _insideHook = true;
    try {
      (_previousDebugPrint ?? debugPrint)(line.trimRight());
      final result = await _channel.invokeMethod<String>('append', {
        'line': line,
      });
      if (result != null && result.isNotEmpty) path = result;
    } catch (e) {
      (_previousDebugPrint ?? debugPrint)('[AppLog] write failed: $e');
    } finally {
      _insideHook = false;
    }
  }

  static Future<void> error(
    String tag,
    Object error, [
    StackTrace? stack,
  ]) {
    final trace = stack ?? StackTrace.current;
    return write(tag, '$error\n$trace');
  }
}
