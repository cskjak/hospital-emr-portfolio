-- treatment.csv → treatment 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/treatment.csv' "STR '\n'"
APPEND INTO TABLE treatment
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(treatment_id, reception_id, start_at DATE "YYYY-MM-DD HH24:MI:SS", end_at DATE "YYYY-MM-DD HH24:MI:SS")
