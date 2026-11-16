-- readings 생체 특징점: 배포된 구버전 클라이언트 호환 + 미보관 동시 달성 (strip 트리거)
--
-- 배경 / 정정 사유:
--   선행 마이그레이션 20260706000001 은 landmarks/features 컬럼을 bare DROP 했으나,
--   당시 스토어 라이브 빌드(v1.0.0+5)의 구버전 클라이언트는 여전히
--     (1) INSERT payload 에 landmarks/features 키를 포함하고,
--     (2) _fromRow 에서 landmarks 를 non-null 로 캐스트한다.
--   → bare DROP 상태에서는 구버전 앱의 저장 실패(PGRST204) 및 History/상담 화면 크래시 발생.
--   (expand/contract 순서 위반: 신규 빌드 배포 전에 contract 를 먼저 수행한 것)
--
-- 이 마이그레이션은 컬럼을 되살리되 "항상 비우는" BEFORE INSERT 트리거로
-- 생체 특징점을 서버에 저장하지 않으면서(미보관 목표 유지) 구버전 앱과의 호환을 회복한다.
--   - landmarks : '{}'(non-null) — 구버전 non-null 캐스트 read 호환
--   - features  : null           — 구버전 nullable 캐스트 read 호환
--   - 기존 저장값은 이미 파기됨(20260706000001 DROP 시 소멸). 재생성 컬럼은 값이 비어 있음.

-- 1) 컬럼 복구 (nullable)
alter table public.readings add column if not exists landmarks jsonb;
alter table public.readings add column if not exists features  jsonb;

-- 2) 백필: 구버전 non-null 캐스트가 크래시하지 않도록 landmarks 를 '{}' 로 채움
update public.readings set landmarks = '{}'::jsonb where landmarks is null;

-- 3) strip 트리거: 모든 INSERT 에서 생체 특징점을 비운다 (구버전이 보내도 저장 안 됨)
create or replace function public.strip_readings_biometrics()
returns trigger as $$
begin
  new.landmarks := '{}'::jsonb;
  new.features  := null;
  return new;
end;
$$ language plpgsql;

drop trigger if exists readings_strip_biometrics on public.readings;
create trigger readings_strip_biometrics
  before insert on public.readings
  for each row execute function public.strip_readings_biometrics();

comment on table public.readings is '관상/손금 분석 결과 (생체 특징점 미보관 — INSERT 시 트리거로 strip)';

-- PostgREST 스키마 캐시 리로드 (재생성 컬럼 인식)
notify pgrst, 'reload schema';

-- 최종 정리(선택, 별도 마이그레이션): 신규 빌드(코드에서 landmarks/features 미전송) 채택 후
--   old client 소멸 시점에 트리거 + 컬럼을 완전히 DROP 하여 스키마를 정돈할 수 있다.
