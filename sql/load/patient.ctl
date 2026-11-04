-- patient.csv → patient 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/patient.csv' "STR '\n'"
APPEND INTO TABLE patient
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(patient_id, patient_name, gender, birth_date DATE "YYYY-MM-DD", phone, registered_at DATE "YYYY-MM-DD HH24:MI:SS")
