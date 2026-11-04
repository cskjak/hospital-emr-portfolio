-- staff.csv → staff 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/staff.csv' "STR '\n'"
APPEND INTO TABLE staff
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(staff_id, staff_name, role_id, dept_id, doctor_id, hire_date DATE "YYYY-MM-DD", status)
