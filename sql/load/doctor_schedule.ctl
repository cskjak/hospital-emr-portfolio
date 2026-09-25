-- doctor_schedule.csv → doctor_schedule 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\doctor_schedule.csv' "STR '\n'"
APPEND INTO TABLE doctor_schedule
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(doctor_id, weekday, session_type)
