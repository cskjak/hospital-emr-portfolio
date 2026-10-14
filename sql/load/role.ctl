-- role.csv → role 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\role.csv' "STR '\n'"
APPEND INTO TABLE role
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(role_id, role_code, role_name)
