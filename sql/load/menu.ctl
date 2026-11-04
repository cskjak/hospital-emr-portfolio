-- menu.csv → menu 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/menu.csv' "STR '\n'"
APPEND INTO TABLE menu
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(menu_id, menu_name, parent_id, sort_order)
