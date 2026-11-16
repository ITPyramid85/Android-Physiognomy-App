/// 환경변수 키 (--dart-define 으로 주입)
class Env {
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://vpjfwwijijjevjmudjol.supabase.co');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwamZ3d2lqaWpqZXZqbXVkam9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5NjA1MjEsImV4cCI6MjA5MTUzNjUyMX0.W0xd9p85e2oAxhZwKcsWXxEXKfWYRZZsNz-3WNILFOE');
  static const String kakaoNativeKey =
      String.fromEnvironment('KAKAO_NATIVE_KEY', defaultValue: '2ea8e92a5d7e09db968309ad326b8579');

  Env._();
}

/// 앱 전역 상수
class AppConst {
  // 카메라
  static const int cameraFpsThrottle = 15;       // 목표 프레임
  static const int frameThrottleMs   = 66;       // 1000/15
  static const int logEveryNFrames   = 30;

  // 분석
  static const int stabilityFrames   = 20;       // ~1.3초 × 15fps
  static const double stabilityScore = 0.7;      // 최소 score 임계값
  /// 비어 있으면 Android 에뮬레이터는 167.114.172.44, 그 외는 127.0.0.1 을 쓴다.
  static const String serverUrlOverride =
      String.fromEnvironment('AURA_SERVER_URL');
  static const int serverPort = 8787;

  // 지원 언어
  static const List<String> supportedLocales = ['ko', 'en', 'ja', 'zh'];

  AppConst._();
}
