-- treatment.csv → treatment 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\treatment.csv' "STR '\n'"
APPEND INTO TABLE treatment
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(treatment_id, reception_id, start_at DATE "YYYY-MM-DD HH24:MI:SS", end_at DATE "YYYY-MM-DD HH24:MI:SS")
