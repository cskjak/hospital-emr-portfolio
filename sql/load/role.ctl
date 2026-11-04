-- role.csv → role 테이블 (저장소 맨 위 폴더에서 실행 · INFILE 경로가 그 폴더 기준)
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET UTF8
INFILE 'data/role.csv' "STR '\n'"
APPEND INTO TABLE role
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(role_id, role_code, role_name)
