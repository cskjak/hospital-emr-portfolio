-- menu.csv → menu 테이블
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'X:\hospital-emr-portfolio\data\menu.csv' "STR '\n'"
APPEND INTO TABLE menu
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(menu_id, menu_name, parent_id, sort_order)
