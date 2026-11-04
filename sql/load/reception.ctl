-- reception.csv → reception 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/reception.csv' "STR '\n'"
APPEND INTO TABLE reception
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(reception_id, patient_id, dept_id, doctor_id, reception_at DATE "YYYY-MM-DD HH24:MI:SS", visit_type, status)
