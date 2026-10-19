# 백업·복구 실습

이 포트폴리오 DB(Oracle 26ai Free, NOARCHIVELOG 모드)에서 백업과 복구를 직접 해 본 기록이다. 원본 테이블은 건드리지 않고 복사본으로 연습한다.

| 순서 | 종류 | 도구 | 상태 |
|---|---|---|---|
| A | 지운 테이블 되살리기 | 휴지통 (`FLASHBACK TABLE`) | ✅ |
| B | 논리 백업 | Data Pump (`expdp` / `impdp`) | 예정 |
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
