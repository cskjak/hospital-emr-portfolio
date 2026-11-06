-- ============================================================
-- 03. 이미 만든 테이블에 CHECK 제약 2개 추가 (수납 총액 = 공단 + 본인 · 진료 끝 >= 시작)
-- 실행: 저장소 맨 위 폴더에서  sqlplus emr@//localhost:1521/FREEPDB1 @sql/03_add_constraints.sql
--       (비밀번호를 물은 뒤 끝까지 실행하고, 마지막 EXIT로 SQL*Plus를 스스로 닫는다)
-- 01번에 이 제약이 들어가기 전에 만든 DB용이다. 새 01번으로 만든 DB에는 이미 있어서 ORA-02264(이미 있는 이름)가 난다.
-- 시험으로 넣는 줄은 6번의 ROLLBACK으로 모두 되돌린다. 제약을 빼려면 ALTER TABLE ... DROP CONSTRAINT 이름
-- ============================================================
SET LINESIZE 200
COLUMN table_name FORMAT A12
COLUMN constraint_name FORMAT A30
COLUMN search_condition_vc FORMAT A60

-- 1. 넣기 전에 규칙을 어기는 줄 세기 (둘 다 0이어야 제약이 들어간다)
SELECT COUNT(*) AS 총액_불일치 FROM payment WHERE total_amount <> insurance_amount + patient_amount;
SELECT COUNT(*) AS 시각_역전 FROM treatment WHERE end_at < start_at;

-- 2. 제약 추가. 기본값(ENABLE VALIDATE)이라 이미 있는 줄도 모두 검사한다
--    어기는 줄이 하나라도 있으면 ORA-02293으로 거부된다
ALTER TABLE payment ADD CONSTRAINT ck_payment_amount_sum
    CHECK (total_amount = insurance_amount + patient_amount);
ALTER TABLE treatment ADD CONSTRAINT ck_treatment_end_after_start
    CHECK (end_at >= start_at);

-- 3. 들어갔는지 확인 (STATUS = ENABLED · VALIDATED = VALIDATED)
SELECT table_name, constraint_name, search_condition_vc, status, validated
FROM user_constraints
WHERE constraint_name IN ('CK_PAYMENT_AMOUNT_SUM', 'CK_TREATMENT_END_AFTER_START')
ORDER BY table_name;

-- 4. 규칙을 어기는 줄 넣어 보기 → 둘 다 ORA-02290 (에러에 제약 이름이 나온다)
--    5332는 취소 접수라 진료 · 수납이 없어서 기본키 · UNIQUE · FK에는 걸리지 않는다
INSERT INTO payment (payment_id, reception_id, paid_at, total_amount, insurance_amount, patient_amount, method)
VALUES (-1, 5332, SYSDATE, 10000, 4000, 5000, '카드');
INSERT INTO treatment (treatment_id, reception_id, start_at, end_at)
VALUES (-1, 5332, SYSDATE, SYSDATE - 10/1440);

-- 5. 금액이 빈칸(NULL)이면 CHECK는 막지 않는다 → 1 행이 생성되었습니다
--    NULL이 끼면 비교 결과가 '알 수 없음'이 되는데, CHECK는 결과가 거짓일 때만 막는다
INSERT INTO payment (payment_id, reception_id, paid_at, total_amount, insurance_amount, patient_amount, method)
VALUES (-2, 5332, SYSDATE, NULL, 4000, 5000, '카드');

-- 6. 시험으로 넣은 줄 되돌리기 → 남은_시험줄 0
ROLLBACK;
SELECT COUNT(*) AS 남은_시험줄 FROM payment WHERE payment_id < 0;

EXIT
