# 백업·복구 실습

이 포트폴리오 DB(Oracle 26ai Free, NOARCHIVELOG 모드)에서 백업과 복구를 직접 해 본 기록이다. 원본 테이블은 건드리지 않고 복사본으로 연습한다.

| 순서 | 종류 | 도구 | 상태 |
|---|---|---|---|
| A | 지운 테이블 되살리기 | 휴지통 (`FLASHBACK TABLE`) | ✅ |
| B | 논리 백업 | Data Pump (`expdp` / `impdp`) | ✅ |
| C | 물리 백업 | RMAN | ✅ |

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
