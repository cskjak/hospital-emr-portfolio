-- staff.csv → staff 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\staff.csv' "STR '\n'"
APPEND INTO TABLE staff
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(staff_id, staff_name, role_id, dept_id, doctor_id, hire_date DATE "YYYY-MM-DD", status)
