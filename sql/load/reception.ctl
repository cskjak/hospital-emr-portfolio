-- reception.csv → reception 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\reception.csv' "STR '\n'"
APPEND INTO TABLE reception
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(reception_id, patient_id, dept_id, doctor_id, reception_at DATE "YYYY-MM-DD HH24:MI:SS", visit_type, status)
