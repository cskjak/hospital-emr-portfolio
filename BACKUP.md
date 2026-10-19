# 백업·복구 실습

이 포트폴리오 DB(Oracle 26ai Free, NOARCHIVELOG 모드)에서 백업과 복구를 직접 해 본 기록이다. 원본 테이블은 건드리지 않고 복사본으로 연습한다.

| 순서 | 종류 | 도구 | 상태 |
|---|---|---|---|
| A | 지운 테이블 되살리기 | 휴지통 (`FLASHBACK TABLE`) | ✅ |
| B | 논리 백업 | Data Pump (`expdp` / `impdp`) | ✅ |
| C | 물리 백업 | RMAN | 예정 |

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
