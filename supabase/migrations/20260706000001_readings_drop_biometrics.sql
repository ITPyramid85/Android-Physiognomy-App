-- readings 생체 특징점 컬럼 제거 (개인정보 최소수집 / 서버 미보관 전환)
--
-- 배경:
--   - landmarks(얼굴 468점 / 손 21점 좌표): 저장 후 소비하는 클라이언트 코드가 전무 (dead data)
--   - features(파생 지표): 상담 프롬프트 경로로 읽히나 키 불일치(snake_case↔camelCase)로
--     실효 없이 저장만 되던 데이터
--   → 클라이언트 저장 중단(선행 커밋 9c2ff19) 후, 서버 컬럼과 기존 저장값을 물리 제거한다.
--
-- DROP COLUMN 이 컬럼 정의 + NOT NULL 제약 + 컬럼 코멘트 + 기존 모든 행의 값을
-- 한 번에 물리적으로 파기한다 (별도 UPDATE ... SET NULL 불필요).

alter table public.readings drop column if exists landmarks;
alter table public.readings drop column if exists features;

comment on table public.readings is '관상/손금 분석 결과 (생체 특징점 미보관)';
