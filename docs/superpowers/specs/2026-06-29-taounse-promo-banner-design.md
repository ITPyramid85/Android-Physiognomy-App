# Aura → 타오운세 유입 배너 설계

> 작성일: 2026-06-29
> 목적: 결과 페이지를 끝까지 본 사용자를 모회사 서비스 `taoist.co.kr`(타오운세)로 유입시켜, 실제 매출이 발생하는 웹으로 연결한다.

## 1. 배경 / 문제

현재 Aura 앱에서 "타오운세"는 앱 내부 AI 어시스턴트의 표시 이름(`aiName`)으로만 쓰이고, 외부 타오운세 사이트로 향하는 유입 동선이 **전혀 없다**. Aura의 온디바이스 분석은 무료이고 매출은 타오운세 웹에서만 발생하므로, 분석 결과를 본 직후의 높은 관심을 웹 유입으로 전환하는 장치가 필요하다.

## 2. 결정 사항 (확정)

| 항목 | 결정 |
|---|---|
| 목적지 | `https://taoist.co.kr` (메인) |
| 추적 | UTM 파라미터 부착 — `utm_source=aura_app`, `utm_medium=result_banner`, `utm_campaign={face|palm}` |
| 배치 | **A안** — 결과 본문 스크롤의 맨 마지막 (종합 섹션 다음, 하단 고정 `_BottomCta` 위) |
| 적용 화면 | 얼굴 결과 + 손금 결과 **양쪽** |
| 열기 방식 | **외부 브라우저** (`LaunchMode.externalApplication`) — 사이트 로그인 세션/쿠키 유지로 결제·가입 전환 유리 |
| 전환 목표 | 타오운세 웹에서의 매출(결제·가입). Aura는 깔때기 역할 |

## 3. 컴포넌트 설계

### 3.1 신규 위젯: `lib/core/widgets/taounse_promo_banner.dart`

- `StatelessWidget`, 공유 위젯 (`lib/core/widgets/`는 기존 공유 위젯 폴더 — camera_stability_card 등 동거).
- 입력 파라미터: `final String campaign;` ('face' | 'palm') 하나만.
- 레이아웃: 앱 톤 통일 — 라운드(`AppRadius`) + 골드/브랜드 그라데이션 배경, 좌측 아이콘(예: `Icons.auto_awesome`), 제목+부제 2줄, 우측 `arrow_forward`. 기존 home_page의 상담 카드 스타일을 참고하되 동일 코드 복붙은 지양.
- 탭 동작:
  ```dart
  final uri = Uri.parse(
    'https://taoist.co.kr'
    '?utm_source=aura_app&utm_medium=result_banner&utm_campaign=$campaign',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
  ```
- 실패 처리: `launchUrl`이 `false` 반환하거나 throw 시 스낵바로 안내(`resultPromoLaunchError` 키). 앱이 죽지 않게 try/catch.

### 3.2 삽입 지점

- **얼굴**: `lib/features/face_reading/result/face_result_page.dart` — `_buildResult`의 메인 `ListView` children 마지막에 `TaounsePromoBanner(campaign: 'face')` append.
- **손금**: `lib/features/palm_reading/result/palm_result_page.dart` — 본문 `ListView`(약 line 245) children 마지막에 `TaounsePromoBanner(campaign: 'palm')` append.
- 스트리밍 중(`isStreaming`)에는 노출하지 않고, 분석 텍스트가 완성된 뒤에만 보이도록 한다(미완성 결과에서 이탈 유도 방지). 로딩/에러 상태에서는 미노출.

## 4. 다국어 (i18n)

ARB 4개 파일(`app_ko/en/ja/zh.arb`) 모두에 신규 키 추가 후 `flutter gen-l10n` 실행. 하드코딩 문자열 금지.

| 키 | KO (예시) |
|---|---|
| `resultPromoTitle` | 더 깊은 풀이가 궁금하세요? |
| `resultPromoSubtitle` | 타오운세에서 사주·관상·타로 전문 분석을 만나보세요 → |
| `resultPromoLaunchError` | 브라우저를 열 수 없습니다. |

EN/JA/ZH는 직역이 아닌 자연스러운 현지화 카피로 작성. 톤: 매출 압박이 아닌 "더 알고 싶다" 호기심 자극(앱의 미니멀·신뢰 톤 유지).

## 5. 의존성 / 플랫폼 설정

- `pubspec.yaml`에 `url_launcher: ^6.3.0` 추가 (현재 미포함).
- **Android 11+ 패키지 가시성**: `android/app/src/main/AndroidManifest.xml`에 `<queries>` 블록 추가하여 http/https `VIEW` intent를 선언한다. 누락 시 릴리스 빌드에서 `launchUrl`이 브라우저를 해석하지 못해 실패한다.
  ```xml
  <queries>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="https" />
    </intent>
  </queries>
  ```

## 6. 테스트 / 검증

- 위젯 테스트: 배너가 face/palm 결과 완성 상태에서 렌더되고, 탭 시 올바른 UTM URL로 `launchUrl`이 호출되는지(런처 모킹) 검증.
- 4개 로케일에서 키가 모두 채워져 빌드 경고 없는지 확인.
- 스트리밍/로딩/에러 상태에서는 배너 미노출 확인.

## 7. 스코프 밖 (이번에 하지 않음 — YAGNI)

- 홈 화면 배너, 상담 화면 링크, 설정 내 "타오운세 더 알아보기".
- 인앱 브라우저(Custom Tab) 모드.
- 결제/가입 자체 처리(웹에서 일어남).
- iOS `LSApplicationQueriesSchemes` (Android 1차 범위이므로 추후).

## 8. 수용 기준

1. 얼굴·손금 결과가 완성되면 본문 스크롤 맨 끝에 타오운세 배너가 보인다.
2. 배너 탭 시 외부 브라우저로 `https://taoist.co.kr?utm_source=aura_app&utm_medium=result_banner&utm_campaign={face|palm}`가 열린다.
3. KO/EN/JA/ZH 4개 언어에서 문구가 현지화되어 출력된다.
4. 릴리스 빌드(Android 11+ 포함)에서 브라우저가 정상적으로 열린다.
5. 스트리밍/로딩/에러 상태에서는 배너가 노출되지 않는다.
