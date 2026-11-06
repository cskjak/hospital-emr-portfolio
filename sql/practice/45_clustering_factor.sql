-- ============================================================
-- 45. 실행계획의 예상과 실제 · clustering factor (SQL.md 41 · 42번에 이어서)
-- 실행: 저장소 맨 위 폴더에서  sqlplus / as sysdba @sql/practice/45_clustering_factor.sql
--       (OS 인증이라 비밀번호를 묻지 않는다 · 끝나면 EXIT로 스스로 닫힌다)
-- sysdba로 하는 이유: DISPLAY_CURSOR는 v$sql_plan 같은 뷰를 읽는데, emr에는 그 권한이 없다
-- 먼저 X:를 붙이고 HOSPITAL이 ONLINE이어야 한다 (INCIDENTS.md 1번 평소 순서)
-- 원본 emr.reception은 읽기만 한다. 4번에서 만드는 복사본은 6번에서 지운다
-- ============================================================
ALTER SESSION SET CONTAINER = FREEPDB1;
SET ECHO ON
SET LINESIZE 200
SET PAGESIZE 200
SET TRIMOUT ON
SET SERVEROUTPUT OFF
COLUMN table_name FORMAT A22
COLUMN index_name FORMAT A24
COLUMN tablespace_name FORMAT A16

-- 0. HOSPITAL이 ONLINE인지 (OFFLINE이면 아래 조회가 ORA-00376으로 막힌다)
SELECT tablespace_name, status FROM dba_tablespaces WHERE tablespace_name = 'HOSPITAL';

-- 1. 41번 인덱스가 없으면 만든다 (이미 있으면 ORA-00955 또는 ORA-01408이 나오는데 괜찮다)
CREATE INDEX emr.idx_reception_patient ON emr.reception (patient_id);

-- 2. 테이블과 인덱스 통계
--    clustering_factor = 인덱스 순서대로 줄을 따라갈 때 테이블 블록이 바뀌는 횟수
--    블록 수에 가까우면 줄이 인덱스 순서대로 모여 있고, 줄 수에 가까우면 흩어져 있다
SELECT table_name, num_rows, blocks, last_analyzed FROM dba_tables
WHERE owner = 'EMR' AND table_name = 'RECEPTION';
SELECT index_name, blevel, leaf_blocks, distinct_keys, clustering_factor, last_analyzed FROM dba_indexes
WHERE owner = 'EMR' AND table_name = 'RECEPTION' ORDER BY index_name;

-- 3. 41 · 42번 쿼리를 실제로 돌리고, 예상(E-Rows · Cost)과 실제(A-Rows · Buffers)를 나란히 본다
-- 3-1. 41번: 환자 1명
SELECT /*+ GATHER_PLAN_STATISTICS */ * FROM emr.reception WHERE patient_id = 10000102;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST +COST'));

-- 3-2. 42번 ①: 환자 10명 (Oracle은 FULL을 고른다)
SELECT /*+ GATHER_PLAN_STATISTICS */ * FROM emr.reception WHERE patient_id BETWEEN 10000001 AND 10000010;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST +COST'));

-- 3-3. 42번 ③: 같은 범위를 인덱스로 강제
SELECT /*+ GATHER_PLAN_STATISTICS INDEX(r idx_reception_patient) */ * FROM emr.reception r WHERE patient_id BETWEEN 10000001 AND 10000010;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST +COST'));

-- 4. 같은 데이터를 환자 순서로 다시 쌓은 복사본 (줄의 물리적 순서만 다르다)
CREATE TABLE emr.reception_by_patient AS SELECT * FROM emr.reception ORDER BY patient_id, reception_id;
CREATE INDEX emr.idx_rbp_patient ON emr.reception_by_patient (patient_id);
EXEC DBMS_STATS.GATHER_TABLE_STATS('EMR', 'RECEPTION_BY_PATIENT');
SELECT table_name, num_rows, blocks FROM dba_tables
WHERE owner = 'EMR' AND table_name = 'RECEPTION_BY_PATIENT';
SELECT index_name, blevel, leaf_blocks, distinct_keys, clustering_factor FROM dba_indexes
WHERE owner = 'EMR' AND table_name = 'RECEPTION_BY_PATIENT';

-- 5. 복사본에서 42번 ①과 같은 범위 (힌트 없음 · 이번에는 Oracle이 인덱스를 고르는지)
SELECT /*+ GATHER_PLAN_STATISTICS */ * FROM emr.reception_by_patient WHERE patient_id BETWEEN 10000001 AND 10000010;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST +COST'));

-- 6. 복사본 지우기 (휴지통에도 남기지 않는다)
DROP TABLE emr.reception_by_patient PURGE;

EXIT
