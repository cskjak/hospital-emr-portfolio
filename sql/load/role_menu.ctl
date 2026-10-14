-- role_menu.csv → role_menu 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\role_menu.csv' "STR '\n'"
APPEND INTO TABLE role_menu
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(role_id, menu_id, can_write)
