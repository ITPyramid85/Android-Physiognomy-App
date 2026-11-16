import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/app_log.dart';

void main() {
  runZonedGuarded(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    // Keep the native hand splash up until the logo image is ready to paint.
    binding.deferFirstFrame();
    AppLog.captureDebugPrint();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLog.error('FlutterError', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLog.error('PlatformError', error, stack);
      return false;
    };
    await AppLog.write('App', 'start');
    try {
      await _startApp();
    } finally {
      binding.allowFirstFrame();
    }
  }, (error, stack) {
    AppLog.error('zone', error, stack);
  });
}

Future<void> _startApp() async {
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Release 빌드에서 Supabase 환경변수 미설정 시 즉시 실패
  // (kDebugMode에서는 경고만 출력하고 계속 진행)
  if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) {
    if (!kDebugMode) {
      throw StateError(
        'SUPABASE_URL 또는 SUPABASE_ANON_KEY 가 설정되지 않았습니다.\n'
        'flutter build --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... 로 빌드하세요.',
      );
    } else {
      debugPrint(
        '[main] WARNING: SUPABASE_URL / SUPABASE_ANON_KEY not set. '
        'Supabase features will be unavailable.',
      );
    }
  }

  // 키 본문은 로그 파일에 남기지 않는다.
  await AppLog.write(
    'App',
    'supabase configured=${Env.supabaseUrl.isNotEmpty} '
        'anonKeyLen=${Env.supabaseAnonKey.length}',
  );

  // 카카오 SDK 초기화 (defaultValue로 키가 항상 존재)
  KakaoSdk.init(nativeAppKey: Env.kakaoNativeKey);
  // 릴리즈 빌드 keyHash 확인용 — Kakao Developer Console에 등록 필요
  KakaoSdk.origin.then((hash) => AppLog.write('Kakao', 'keyHash=$hash'));

  await AppLog.write('App', 'skip on-device Gemma; inference runs on the Python server');

  // Supabase 초기화
  if (Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  await AppLog.write('App', 'runApp log=${AppLog.path ?? "Download/aura-log.txt"}');
  await _precacheHandSeal();
  runApp(const ProviderScope(child: AuraApp()));
}

Future<void> _precacheHandSeal() async {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  final ratio = views.isEmpty ? 3.0 : views.first.devicePixelRatio;
  final provider = const AssetImage('assets/icon/hand_seal.png');
  final stream = provider.resolve(ImageConfiguration(devicePixelRatio: ratio));
  final done = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    },
  );
  stream.addListener(listener);
  await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
}
