-- doctor_schedule.csv → doctor_schedule 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/doctor_schedule.csv' "STR '\n'"
APPEND INTO TABLE doctor_schedule
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(doctor_id, weekday, session_type)
