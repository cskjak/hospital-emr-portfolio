# 백업·복구 실습

이 포트폴리오 DB(Oracle 26ai Free)에서 백업과 복구를 직접 해 본 기록이다. 원본 테이블은 건드리지 않고 복사본으로 연습한다. A~C는 NOARCHIVELOG 모드에서 했고, D에서 ARCHIVELOG 모드로 바꿨다.

| 순서 | 종류 | 도구 | 상태 |
|---|---|---|---|
| A | 지운 테이블 되살리기 | 휴지통 (`FLASHBACK TABLE`) | ✅ |
| B | 논리 백업 | Data Pump (`expdp` / `impdp`) | ✅ |
| C | 물리 백업 | RMAN | ✅ |
| D | ARCHIVELOG 전환 | `ALTER DATABASE ARCHIVELOG` | ✅ |
| E | 열린 채 백업 + 아카이브 로그 정리 | RMAN | ✅ |
| F | 데이터 파일을 지우고 되살리기 | RMAN (`RESTORE` · `RECOVER`) | ✅ |

## A. 지운 테이블 되살리기 (휴지통)

```sql
-- 1. 복사본 만들기
CREATE TABLE reception_copy AS SELECT * FROM reception;
SELECT COUNT(*) FROM reception_copy;   -- 9362

-- 2. 지우기
DROP TABLE reception_copy;
SELECT COUNT(*) FROM reception_copy;   -- ORA-00942: 테이블 또는 뷰가 존재하지 않습니다

-- 3. 휴지통 보기
SELECT object_name, original_name, droptime FROM user_recyclebin;
```

| OBJECT_NAME | ORIGINAL_NAME | DROPTIME |
|---|---|---|
| `BIN$F0kY9JgvRcKCOwSXN/ArWQ==$0` | RECEPTION_COPY | 2026-10-20:02:08:33 |

```sql
-- 4. 되살리기
FLASHBACK TABLE reception_copy TO BEFORE DROP;   -- 플래시백이 완료되었습니다.
SELECT COUNT(*) FROM reception_copy;             -- 9362
```

### PURGE로 지우면

```sql
DROP TABLE reception_copy PURGE;
SELECT object_name, original_name, droptime FROM user_recyclebin;   -- 선택된 레코드가 없습니다.
FLASHBACK TABLE reception_copy TO BEFORE DROP;                      -- ORA-38305: 객체가 RECYCLE BIN에 없음
```

| | `DROP TABLE` | `DROP TABLE ... PURGE` |
|---|---|---|
| 휴지통 | `BIN$...` 이름으로 남음 | 비어 있음 |
| `FLASHBACK` | 성공 · 9,362줄 | ORA-38305 |

휴지통이 보관하는 것은 `DROP TABLE`로 지운 테이블이다. `PURGE`로 지운 테이블은 B의 백업 파일로 되살려야 한다.

**해석:** 드랍만 하면 테이블이 휴지통에 남아서 플래시백으로 9362줄이 돌아왔다. 그러나 퍼지를 붙이면 휴지통이 아닌 바로 영구 삭제로 되돌릴 수 없었다.

## B. 백업 파일로 되살리기 (Data Pump)

A에서 `PURGE`로 지운 테이블은 휴지통으로 되살릴 수 없었다. 이번에는 지우기 전에 `expdp`로 백업 파일을 만들고, `PURGE`한 뒤 `impdp`로 되살린다.

### 1. 권한 (sysdba)

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
GRANT READ, WRITE ON DIRECTORY DATA_PUMP_DIR TO emr;
```

emr에는 처음에 `CREATE SESSION · TABLE · VIEW · SEQUENCE` 권한만 있어서, 백업 파일을 쓸 폴더(`DATA_PUMP_DIR`) 권한을 따로 줬다.

### 2. 복사본 → 백업 파일 (expdp)

```sql
CREATE TABLE reception_copy AS SELECT * FROM reception;
SELECT COUNT(*) FROM reception_copy;   -- 9362

HOST expdp emr/<비밀번호>@localhost:1521/FREEPDB1 TABLES=reception_copy DIRECTORY=DATA_PUMP_DIR DUMPFILE=reception_copy.dmp LOGFILE=exp_reception_copy.log
```

```
. . "EMR"."RECEPTION_COPY"   400.8 KB    9362행이 엑스포트됨
"EMR"."SYS_EXPORT_TABLE_01" 작업이 ... elapsed 0 00:00:15에서 성공적으로 완료됨
```

### 3. PURGE → 백업 파일에서 되살리기 (impdp)

```sql
DROP TABLE reception_copy PURGE;
SELECT object_name, original_name FROM user_recyclebin;   -- 선택된 레코드가 없습니다.

HOST impdp emr/<비밀번호>@localhost:1521/FREEPDB1 TABLES=reception_copy DIRECTORY=DATA_PUMP_DIR DUMPFILE=reception_copy.dmp LOGFILE=imp_reception_copy.log
```

```
. . "EMR"."RECEPTION_COPY"   400.8 KB    9362행이 임포트됨
"EMR"."SYS_IMPORT_TABLE_01" 작업이 ... elapsed 0 00:00:20에서 성공적으로 완료됨
```

```sql
SELECT COUNT(*) FROM reception_copy;   -- 9362
```

### A와 비교

| | A. 휴지통 | B. 백업 파일 |
|---|---|---|
| 미리 해 둘 것 | 없음 | `expdp`로 파일 만들기 |
| `PURGE` 뒤 | ORA-38305 · 되살릴 수 없음 | `impdp`로 9,362줄 |
| 되돌아가는 시점 | 지운 순간 그대로 | 백업 파일을 만든 시점 |

`HOST` 안에서 실행하면 비밀번호 입력 칸이 뜨지 않고 바로 ORA-01017이 나서, 명령 줄에 비밀번호를 넣었다. Oracle은 작업 기록에 `emr/********`로 가려서 적는다.

**해석:** 휴지통에 담았을 땐 플래시백으로 복구가 가능한데 휴지통이 아닌 퍼지로 영구 삭제를 하게 되면 휴지통으로는 복구가 불가능하다. 하지만 지우기 전에 expdp로 백업 파일을 만들어 두면 impdp로 9362줄을 복구할 수 있다.

## C. DB 전체 물리 백업 (RMAN)

### 1. 로그 모드 확인 (sqlplus · sysdba)

```
SQL> ARCHIVE LOG LIST
데이터베이스 로그 모드              아카이브 모드가 아님
자동 아카이브             사용 안함으로 설정됨
```

### 2. DB가 열린 채로 백업 → 거부

```
C:\> rman target /
RMAN> BACKUP DATABASE FORMAT 'C:\oracle_backup\%U';
RMAN-06149: NOARCHIVELOG 모드에서 BACKUP DATABASE를 수행할 수 없습니다.
```

열린 DB는 백업하는 동안에도 데이터 파일이 바뀐다. NOARCHIVELOG에서는 그 사이 변경 기록이 보관되지 않아 시점이 섞인 백업을 맞출 방법이 없으므로, Oracle이 처음부터 거부한다.

### 3. MOUNT에서 백업

```
RMAN> SHUTDOWN IMMEDIATE;
RMAN> STARTUP MOUNT;
RMAN> BACKUP DATABASE FORMAT 'C:\oracle_backup\%U';
RMAN> ALTER DATABASE OPEN;
RMAN> SELECT name, open_mode FROM v$pdbs;   -- FREEPDB1 READ WRITE
RMAN> LIST BACKUP SUMMARY;
```

| 백업 조각 | 들어간 데이터 파일 | 걸린 시간 | 크기 |
|---|---|---:|---:|
| 1 | CDB 본체 4개 (SYSTEM · SYSAUX · UNDO · USERS) | 15초 | 1,531MB |
| 2 | FREEPDB1 5개 (`X:\ORADATA\HOSPITAL01.DBF` 포함) | 7초 | 776MB |
| 3 | PDB$SEED 3개 | 15초 | 564MB |
| 자동 | 컨트롤 파일 + SPFILE | | |

데이터 파일 12개(3.8GB)가 조각 3개(2.9GB)에 들어갔다. RMAN은 쓰지 않은 빈 블록을 건너뛴다. `LIST BACKUP SUMMARY`의 `B F A` = 백업 세트 · 전체 백업 · 사용 가능.

### 4. 되살릴 수 있는지 검사

```
RMAN> RESTORE DATABASE VALIDATE;
```

조각 3개 모두 `검증 완료`. `VALIDATE`는 백업을 읽어서 검사만 하고 데이터 파일은 덮어쓰지 않는다.

### NOARCHIVELOG가 바꾸는 것

| 내용 | 근거 |
|---|---|
| 열린 DB는 백업할 수 없고 MOUNT에서만 된다 | 실험 (RMAN-06149) |
| 데이터 파일 하나가 고장 나면 인스턴스 전체가 종료된다 | 로그 ([INCIDENTS.md](INCIDENTS.md) 2번 · ORA-01242) |
| ARCHIVELOG였다면 고장 난 파일만 offline으로 내리고 DB는 계속 돈다 | Oracle 문서 기준 · 직접 확인은 안 함 |
| 되살리면 백업한 시점으로만 돌아가고, 그 뒤 변경은 사라진다 | 개념 · 직접 확인은 안 함 |

**해석:** DB가 열려 있으면 오라클 자체에서 백업 시도조차 차단된다. 그래서 마운트하고 백업을 시도하니 정상적으로 가능했다. 데이터 파일 12개(3.8GB)가 백업 조각 3개(2.9GB)로 줄었다. VALIDATE로 검사만 해서 건드린 건 없다.

## D. ARCHIVELOG 전환

리두 로그(변경 기록)는 3개 × 200MB를 돌아가며 쓴다. NOARCHIVELOG에서는 다 찬 로그를 그대로 덮어쓰고, ARCHIVELOG에서는 덮어쓰기 전에 아카이브 로그 파일로 복사해 둔다.

### 1. 전환 전 확인 (sqlplus · sysdba)

```
SQL> ARCHIVE LOG LIST
데이터베이스 로그 모드              아카이브 모드가 아님
아카이브 대상            C:\app\<사용자>\product\26ai\dbhomeFree\RDBMS

SQL> SHOW PARAMETER log_archive_dest_1        -- 비어 있음
SQL> SHOW PARAMETER db_recovery_file_dest     -- 비어 있음 (FRA 없음)
SQL> SELECT group#, bytes/1024/1024 AS mb, status FROM v$log;   -- 3개 × 200MB
```

위치를 따로 정하지 않으면 Oracle 프로그램 폴더(`RDBMS`)에 쌓인다. 프로그램 파일과 섞이지 않게 전용 폴더를 만든다. `X:`는 꺼내 두는 드라이브라 쓰지 않는다.

### 2. 위치 지정 → 전환

```sql
HOST mkdir C:\oracle_archive
ALTER SYSTEM SET log_archive_dest_1='LOCATION=C:\oracle_archive' SCOPE=BOTH;

SHUTDOWN IMMEDIATE
STARTUP MOUNT
ALTER DATABASE ARCHIVELOG;     -- 로그 모드는 MOUNT 상태에서만 바꿀 수 있다
ALTER DATABASE OPEN;
SELECT name, open_mode FROM v$pdbs;   -- FREEPDB1 READ WRITE
```

| 칸 | 전환 전 | 전환 후 |
|---|---|---|
| 데이터베이스 로그 모드 | 아카이브 모드가 아님 | 아카이브 모드 |
| 자동 아카이브 | 사용 안함 | 사용 |
| 아카이브 대상 | `...\dbhomeFree\RDBMS` | `C:\oracle_archive` |

### 3. 아카이브 파일이 생기는지 확인

```sql
HOST dir C:\oracle_archive     -- 0 File(s)
ALTER SYSTEM SWITCH LOGFILE;   -- 다 찬 것으로 치고 다음 리두 로그로 넘김
HOST dir C:\oracle_archive
```

| 칸 | SWITCH 전 | SWITCH 후 |
|---|---:|---:|
| 파일 수 | 0 | 1 (`ARC0000000027_1244943258.0001`) |
| 파일 크기 | | 118,377,984 bytes |
| C: 여유 공간 | 44,346,044,416 | 44,227,665,920 |

여유 공간이 줄어든 양(118,378,496)이 파일 크기와 거의 같다. 200MB가 다 차기 전에 넘겨서 그때까지 쓴 만큼만 복사됐다.

### 파일 이름 규칙

`SHOW PARAMETER log_archive_format` → `ARC%S_%R.%T`

| 규칙 | 실제 | 뜻 |
|---|---|---|
| `%S` | `0000000027` | 로그 순서 번호 |
| `%R` | `1244943258` | RESETLOGS ID |
| `%T` | `0001` | 스레드 번호 |

```
SQL> SELECT group#, sequence#, status FROM v$log;
    GROUP#  SEQUENCE# STATUS
         1         28 CURRENT
         2         26 INACTIVE
         3         27 ACTIVE
```

파일 이름의 `27`과 방금까지 쓰던 로그(GROUP 3)의 SEQUENCE# 27이 같다.

### `ARCHIVE LOG LIST`의 순서 번호가 v$log와 다르다

| 시점 | 칸 | `ARCHIVE LOG LIST` | v$log 실제 |
|---|---|---:|---:|
| SWITCH 직후 (v$log 26 · 27 · 28) | 가장 오래된 | 28 | 26 |
| | 아카이브할 다음 | 27 | 28 |
| | 현재 | 26 | 28 (CURRENT) |
| E 정리 뒤 (v$log 28 · 29 · 30) | 가장 오래된 | 30 | 28 |
| | 아카이브할 다음 | 30 | 30 |
| | 현재 | 29 | 30 (CURRENT) |

처음엔 한글 메시지 문제로 의심했다. 그래서 `set NLS_LANG=AMERICAN_AMERICA.AL32UTF8`로 영어 창을 띄워 같은 순간에 비교했는데, 영어(`Oldest 30 · Next 30 · Current 29`)도 한글과 숫자가 같았다. 언어 문제는 아니다. 원인은 확인하지 못했다. 순서 번호는 원본인 v$log로 확인한다.

**해석:** 아카이브 모드로 바꾸고 SWITCH LOGFILE을 하니 파일이 0개에서 1개로 생겼다.

## E. 열린 채 백업 + 아카이브 로그 정리 (RMAN)

### 1. C와 같은 명령을 DB가 열린 채로 다시 실행

```
RMAN> BACKUP DATABASE FORMAT 'C:\oracle_backup\%U';
```

| | C (NOARCHIVELOG) | E (ARCHIVELOG) |
|---|---|---|
| DB 상태 | 열림 | 열림 |
| 결과 | RMAN-06149 거부 | 조각 3개 + 컨트롤 파일 자동 백업 |
| `LIST BACKUP SUMMARY` 키 | 1~4 | 5~8 |
| 조각별 걸린 시간 | 15 · 7 · 15초 | 15 · 7 · 15초 |

C의 에러 문구가 "**NOARCHIVELOG 모드에서** BACKUP DATABASE를 수행할 수 없습니다"였다. 거부된 이유는 DB가 열려 있어서가 아니라 로그 모드였다. ARCHIVELOG에서는 백업하는 동안 바뀐 내용이 아카이브 로그로 남는다.

### 2. 아카이브 로그 백업

```
RMAN> LIST ARCHIVELOG ALL;                                   -- 시퀀스 27 하나
RMAN> BACKUP ARCHIVELOG ALL FORMAT 'C:\oracle_backup\%U';
RMAN> LIST BACKUP OF ARCHIVELOG ALL;
```

`BACKUP ARCHIVELOG ALL`은 시작할 때 지금 쓰던 리두 로그부터 아카이브한다(`현재 로그가 아카이브됨`). 처음에 `%U`를 `$U`로 잘못 쳐서 ORA-09314(논리 이름 변환 오류)로 실패했고, 그때도 로그가 하나 아카이브돼서 백업 대상은 3개가 됐다.

| Seq | Low SCN (시작) | 다음 SCN (끝) |
|---|---:|---:|
| 27 | 16541080 | 16605067 |
| 28 | 16605067 | 16608767 |
| 29 | 16608767 | 16608870 |

백업 집합 9 (121.54MB)에 3개가 모두 들어갔다. 한 파일의 끝 SCN이 다음 파일의 시작 SCN과 같아서 빠진 변경 기록이 없다. 28은 1번의 데이터베이스 백업(19:02) 시간을 포함한다. 열린 채로 한 백업을 되살리려면 이런 아카이브 로그가 같이 있어야 한다(Oracle 문서 기준 · 복구는 직접 해 보지 않음).

### 3. 백업된 것만 삭제

```
RMAN> DELETE ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;
```

지울 목록(27 · 28 · 29)을 보여 주고 `YES`를 받은 뒤 `3 객체를 삭제함`. 백업 확인(`LIST BACKUP OF ARCHIVELOG ALL`) 전에 지우지 않는다. 2번의 첫 시도가 실패했을 때는 이 목록이 비어 있었다(`사양이 저장소의 백업과 일치하지 않습니다`).

### 4. 확인

| 명령 | 결과 |
|---|---|
| `LIST ARCHIVELOG ALL` | 없음 (`사양이 저장소의 아카이브된 로그와 일치하지 않습니다`) |
| `HOST 'dir C:\oracle_archive'` | 0 File(s) |
| `LIST BACKUP OF ARCHIVELOG ALL` | 백업 집합 9 그대로 (27 · 28 · 29) |

**해석:** NOARCHIVELOG에서는 DB가 열린 채로 백업이 거부됐는데, ARCHIVELOG로 바꾸니 같은 명령으로 성공했다. 백업은 정상적으로 남아있고 RMAN 기록상 원본은 삭제 됐고 실제 폴더에서도 0 파일로 삭제된게 확인이 됐다.

## F. 데이터 파일을 지우고 되살리기 (RMAN RESTORE · RECOVER)

C~E에서는 백업을 만들고 `VALIDATE`로 읽어 보기만 했다. 여기서는 데이터 파일을 실제로 지우고, RMAN으로 되살렸을 때 백업 **뒤에** 넣은 줄까지 돌아오는지 확인한다. 원본 데이터 파일(`X:\ORADATA\HOSPITAL01.DBF`)을 지울 수는 없으므로, 실습용 테이블스페이스를 따로 만들어 그 파일만 지웠다.

| 단어 | 뜻 |
|---|---|
| 테이블스페이스 (tablespace) | 테이블이 들어가는 저장 구역. 실제 파일(데이터 파일)을 하나 이상 가진다 |
| OFFLINE / ONLINE | 테이블스페이스를 잠시 쓰지 않는 상태로 내리기 / 다시 쓰는 상태로 올리기 |
| RESTORE (리스토어) | 백업에서 파일을 원래 자리에 다시 갖다 놓기. 내용은 백업한 시점으로 돌아간다 |
| RECOVER (리커버) | 갖다 놓은 파일에 백업 뒤의 변경 기록(리두 로그 · 아카이브 로그)을 다시 적용하기 |

### 1. 실습용 테이블스페이스 (sqlplus · sysdba)

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
HOST mkdir C:\oracle_test
CREATE TABLESPACE rman_test DATAFILE 'C:\oracle_test\rman_test01.dbf' SIZE 50M;
ALTER USER emr QUOTA UNLIMITED ON rman_test;
CREATE TABLE emr.dl_test (id NUMBER, val NUMBER) TABLESPACE rman_test;
INSERT INTO emr.dl_test VALUES (1, 10);
INSERT INTO emr.dl_test VALUES (2, 200);
COMMIT;
SELECT file_id, file_name FROM dba_data_files WHERE tablespace_name = 'RMAN_TEST';   -- 18 · C:\ORACLE_TEST\RMAN_TEST01.DBF
```

`dl_test`는 [LOCKS.md](LOCKS.md) B의 데드락 실습에도 썼다(바꾼 값은 ROLLBACK으로 되돌림). 따로 적지 않았는데 `rman_test`는 BIGFILE(파일 하나짜리 테이블스페이스)로 만들어졌다. 26ai의 기본값이다.

### 2. 테이블스페이스 하나만 백업 (RMAN · 23:10)

```
RMAN> BACKUP TABLESPACE FREEPDB1:RMAN_TEST FORMAT 'C:\oracle_backup\%U';
RMAN> LIST BACKUP OF TABLESPACE FREEPDB1:RMAN_TEST;
```

| 칸 | 값 |
|---|---|
| 백업 집합 (BS 키) | 12 |
| 조각 | `C:\ORACLE_BACKUP\0D55Q43C_13_1_1` |
| 크기 | 6.14MB (데이터 파일은 50MB · C와 같이 빈 블록은 건너뜀) |
| Ckp SCN | 16777383 |
| 담긴 내용 | dl_test 2줄 (1 · 2) |

RMAN은 CDB 맨 위(root)에 접속하므로, PDB 안의 테이블스페이스는 앞에 `FREEPDB1:`을 붙인다. 같은 이유로 RMAN 창에서 친 `INSERT INTO emr.dl_test ...`는 `ORA-00942 "EMR"."DL_TEST"이(가) 존재하지 않습니다`로, `ALTER TABLESPACE rman_test ONLINE`은 `ORA-00959 테이블스페이스 'RMAN_TEST'이(가) 존재하지 않습니다`로 실패했다. 둘 다 FREEPDB1에 접속한 sqlplus 관리 창에서 다시 쳤다.

### 3. 백업 뒤에 줄 넣기 (sqlplus · 23:37~)

```sql
INSERT INTO emr.dl_test VALUES (4, 400);
COMMIT;
INSERT INTO emr.dl_test VALUES (3, 300);
COMMIT;
INSERT INTO emr.dl_test VALUES (3, 300);
COMMIT;
SELECT * FROM emr.dl_test ORDER BY id;   -- 1 · 2 · 3 · 3 · 4 → 5줄
```

3번 줄은 같은 명령을 두 번 쳐서 두 개가 들어갔다. 백업 뒤에 넣은 줄이 몇 개든 모두 돌아오는지를 보는 실험이라 그대로 두었다. 이제 백업에는 2줄, 테이블에는 5줄이 있다.

### 4. 지우기 전 확인

| 확인 | 명령 | 결과 |
|---|---|---|
| 이 파일에 무엇이 들어 있나 | `SELECT owner, segment_name FROM dba_segments WHERE tablespace_name = 'RMAN_TEST';` | EMR · DL_TEST 한 줄 |
| 지울 파일이 정확히 이것인가 | `HOST dir C:\oracle_test` | RMAN_TEST01.DBF 하나 (52,436,992바이트) |
| 이 테이블을 쓰는 emr 세션이 남았나 | `SELECT sid, status FROM v$session WHERE username = 'EMR';` | 없음 |
| 백업을 읽을 수 있나 | `RESTORE TABLESPACE FREEPDB1:RMAN_TEST VALIDATE;` | 검증 완료 · 데이터 파일 수정 시각은 23:10:36 그대로 |

52,436,992바이트는 50MB(52,428,800)에 파일 머리 블록 하나(8,192)를 더한 크기다.

### 5. 파일 삭제 → ORA-01157 (sqlplus · 23:41)

```
관리> ALTER TABLESPACE rman_test OFFLINE;
테이블스페이스가 변경되었습니다.

관리> HOST del C:\oracle_test\rman_test01.dbf
관리> HOST dir C:\oracle_test
               0 File(s)              0 bytes

관리> ALTER TABLESPACE rman_test ONLINE;
ORA-01157: 데이터 18 파일을 식별 또는 잠금 할 수 없습니다- DBWR 추적 파일을 보십시오
ORA-01110: 18 데이터 파일: 'C:\ORACLE_TEST\RMAN_TEST01.DBF'
```

[INCIDENTS.md](INCIDENTS.md) 1번 · 3번과 같은 에러다. 그때는 X: 드라이브가 붙어 있지 않아 파일을 찾지 못했고, 이번에는 파일이 없어서 찾지 못했다. 이 동안 DB는 내려가지 않았고, 관리 창과 RMAN 창 모두 명령을 계속 받았다.

### 6. RESTORE → ORA-01113 (23:43)

```
RMAN> RESTORE TABLESPACE FREEPDB1:RMAN_TEST;
채널 ORA_DISK_1: 데이터 파일 00018을(를) C:\ORACLE_TEST\RMAN_TEST01.DBF(으)로 복원하는 중입니다.
채널 ORA_DISK_1: 백업 조각 C:\ORACLE_BACKUP\0D55Q43C_13_1_1에서 읽는 중입니다.
채널 ORA_DISK_1: 복원 완료, 경과 시간: 00:00:01
```

```
관리> HOST dir C:\oracle_test
2026-10-25  오후 11:43        52,436,992 RMAN_TEST01.DBF

관리> ALTER TABLESPACE rman_test ONLINE;
ORA-01113: 18 파일이 매체 복구되어야 합니다
ORA-01110: 18 데이터 파일: 'C:\ORACLE_TEST\RMAN_TEST01.DBF'
```

백업 조각은 6.14MB였지만 돌아온 파일은 원래 크기(52,436,992바이트)다. 파일이 생기자 에러가 바뀌었다. ORA-01157(파일을 찾을 수 없음)이 ORA-01113(매체 복구가 필요함)이 됐다. 파일 내용이 백업 시점(SCN 16777383)에 머물러 있어서, 그 뒤 변경을 적용하기 전에는 열 수 없다는 뜻이다.

### 7. RECOVER → ONLINE → 5줄 (23:46)

```
RMAN> RECOVER TABLESPACE FREEPDB1:RMAN_TEST;
미디어 복구를 시작합니다
매체 복구 완료, 경과 시간: 00:00:00
```

```
관리> ALTER TABLESPACE rman_test ONLINE;
테이블스페이스가 변경되었습니다.

관리> SELECT * FROM emr.dl_test ORDER BY id;

        ID        VAL
---------- ----------
         1         10
         2        200
         3        300
         3        300
         4        400
```

RECOVER 화면에는 아카이브 로그 이름이 나오지 않았다. `v$log`를 보면 그 까닭이 보인다.

| 리두 로그 시퀀스 | 상태 | 시작 SCN | 시작 시각 |
|---|---|---:|---|
| 31 | INACTIVE · 아카이브됨 | 16666845 | 10-21 01:00 |
| 32 | CURRENT · 아카이브 안 됨 | 16743041 | 10-25 22:16 |

지금 쓰는 32번이 백업 SCN(16777383)보다 앞에서 시작했다. 백업 뒤 변경이 모두 아직 아카이브되지 않은 온라인 리두 로그 안에 있었으므로, 이번 복구에는 아카이브 로그가 쓰이지 않았다(화면과 `v$log` 기준).

### 정리

| 시점 | 데이터 파일 | `ONLINE` 결과 | dl_test |
|---|---|---|---|
| 23:10 백업 | 있음 | | 2줄 → 백업 집합 12 |
| 23:37~ 줄 넣기 | 있음 | | 5줄 (백업 뒤 3줄) |
| 23:41 삭제 | 없음 | ORA-01157 파일을 찾을 수 없음 | 볼 수 없음 |
| 23:43 RESTORE | 있음 (백업 시점) | ORA-01113 매체 복구 필요 | 볼 수 없음 |
| 23:46 RECOVER | 있음 (삭제 직전 시점) | 성공 | **5줄** |

C · E에서 "직접 확인은 안 함"으로 남겨 둔 내용 가운데 이번에 확인한 것:

| 앞에서 남겨 둔 것 | F에서 |
|---|---|
| (E) 열린 채로 한 백업을 되살리려면 아카이브 로그가 같이 있어야 한다 · 복구는 직접 해 보지 않음 | DB가 열린 채로 한 백업(23:10)을 RESTORE + RECOVER로 되살렸다. 이번에 필요한 변경은 온라인 리두 로그에 있었다 |
| (C) 되살리면 백업한 시점으로만 돌아가고, 그 뒤 변경은 사라진다 (NOARCHIVELOG 기준) | ARCHIVELOG인 지금은 RESTORE만 하면 백업 시점, RECOVER까지 하면 백업 뒤 3줄도 돌아왔다. NOARCHIVELOG에서는 해 보지 않았다 |

**해석:** 파일을 지운 뒤 `ONLINE`을 치니 파일이 없어서 찾을 수 없다는 에러(ORA-01157)가 확인됐다. RESTORE를 실행하자 백업에서 파일이 원래 자리에 다시 놓여 DBF가 다시 보였다. 파일은 다시 생겼지만 `ONLINE`을 치니 이번엔 ORA-01113(매체 복구 필요)이 나왔다. 그래서 RECOVER를 실행한 뒤 `ONLINE`으로 바꿔 보니 성공했고, 결과는 5줄이 나왔다. 백업 시점의 2줄에 RECOVER가 백업 뒤에 넣은 3줄을 다시 적용했기 때문이다.
