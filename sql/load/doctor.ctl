-- doctor.csv → doctor 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\doctor.csv' "STR '\n'"
APPEND INTO TABLE doctor
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(doctor_id, doctor_name, dept_id, position, hire_date DATE "YYYY-MM-DD")
