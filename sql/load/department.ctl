-- department.csv → department 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\department.csv' "STR '\n'"
APPEND INTO TABLE department
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(dept_id, dept_code, dept_name, floor)
