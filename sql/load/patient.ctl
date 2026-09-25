-- patient.csv → patient 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\patient.csv' "STR '\n'"
APPEND INTO TABLE patient
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(patient_id, patient_name, gender, birth_date DATE "YYYY-MM-DD", phone, registered_at DATE "YYYY-MM-DD HH24:MI:SS")
