-- doctor.csv → doctor 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/doctor.csv' "STR '\n'"
APPEND INTO TABLE doctor
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(doctor_id, doctor_name, dept_id, position, hire_date DATE "YYYY-MM-DD")
