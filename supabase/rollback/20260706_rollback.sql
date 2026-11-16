-- Rollback (dev/staging 용) — 20260706 생체 특징점 관련 변경 되돌리기
--
-- 현재 배포 상태: readings.landmarks/features 컬럼 존재(nullable) + strip 트리거로 항상 비움.
-- 주의: 원본 생체 데이터는 이미 물리 파기되어 복구 불가능하다. 아래는 스키마 구조만 다룬다.

-- 트리거/함수 제거 (컬럼은 구버전 클라이언트 호환을 위해 유지)
drop trigger if exists readings_strip_biometrics on public.readings;
drop function if exists public.strip_readings_biometrics();

comment on table public.readings is '관상/손금 분석 결과';

-- 컬럼 코멘트 원복(선택)
comment on column public.readings.landmarks is 'MediaPipe 랜드마크 좌표 배열';
comment on column public.readings.features  is '파생 지표: eye_span, face_height, nose_ratio, mouth_width, symmetry';

notify pgrst, 'reload schema';
