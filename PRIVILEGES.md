# DB 권한 실습

이 포트폴리오 DB(Oracle 26ai Free)에서 읽기 전용 계정을 만들고, 권한을 하나씩 주고 빼면서 결과를 확인한 기록이다.

README 31~40번은 앱 안의 권한(`role` · `menu` · `role_menu` 테이블)을 SQL로 조회했다. 여기서는 DB 자체의 권한을 쓴다.

| 단어 | 뜻 |
|---|---|
| GRANT | 권한 주기 · `GRANT 무엇을 TO 누구에게` |
| REVOKE | 권한 회수 · `REVOKE 무엇을 FROM 누구에게서` |
| ROLE | 권한 묶음 |

## 1. 계정 만들기 (sysdba)

```sql
sqlplus / as sysdba
ALTER SESSION SET CONTAINER = FREEPDB1;   -- emr가 있는 PDB로 이동 (안 하면 CDB$ROOT)
SHOW CON_NAME                             -- FREEPDB1
CREATE USER viewer IDENTIFIED BY <비밀번호>;
```

## 2. 권한 없이 접속 → 거부

```
SQL> CONNECT viewer/<비밀번호>@localhost:1521/FREEPDB1
ORA-01045: 로그인이 거부되었습니다. 사용자 VIEWER에게 CREATE SESSION 권한이 없습니다.
```

## 3. 접속 권한 주기

```sql
GRANT CREATE SESSION TO viewer;
```

`GRANT SELECT TO viewer`처럼 권한 이름이 아닌 단어를 쓰면 Oracle은 그 단어를 역할 이름으로 읽는다(`ORA-01919: 'SELECT' 롤이 존재하지 않습니다`).

## 4. 테이블 권한 없이 조회 → 거부

```
SQL> SELECT COUNT(*) FROM emr.reception;
ORA-00942: 테이블 또는 뷰 "EMR"."RECEPTION"이(가) 존재하지 않습니다.
```

테이블은 있다(emr로 조회하면 9,362줄). 권한이 없는 계정에게는 테이블이 있다는 사실도 알려 주지 않는다.

## 5. 역할에 권한을 담아 계정에 주기 (sysdba)

```sql
CREATE ROLE emr_read;
GRANT SELECT ON emr.reception TO emr_read;   -- 권한 → 역할
GRANT emr_read TO viewer;                    -- 역할 → 계정
```

```
SELECT ON emr.reception  →  emr_read (역할)  →  viewer (계정)
```

## 6. 조회 / 지우기

```
SQL> SELECT COUNT(*) FROM emr.reception;
      9362

SQL> DELETE FROM emr.reception WHERE reception_id = -1;
ORA-41900: DELETE 권한이 "EMR"."RECEPTION"에 누락되었습니다.
```

`reception_id = -1`인 줄은 없으므로, 권한이 있었더라도 지워지는 줄은 0줄이다.

## 7. 역할 회수 (sysdba) → 다시 거부

```sql
REVOKE emr_read FROM viewer;
```

viewer로 새로 접속한 뒤:

```
SQL> SELECT * FROM session_roles;
선택된 레코드가 없습니다.

SQL> SELECT COUNT(*) FROM emr.reception;
ORA-00942: 테이블 또는 뷰 "EMR"."RECEPTION"이(가) 존재하지 않습니다.
```

## 정리

| 단계 | viewer가 가진 것 | 시도 | 결과 |
|---|---|---|---|
| 2 | 없음 | 접속 | ❌ ORA-01045 |
| 3 | CREATE SESSION | 접속 | ✅ |
| 4 | CREATE SESSION | SELECT | ❌ ORA-00942 (존재하지 않음) |
| 6 | + 역할 emr_read | SELECT | ✅ 9,362 |
| 6 | + 역할 emr_read | DELETE | ❌ ORA-41900 (권한 누락) |
| 7 | 역할 회수 | SELECT | ❌ ORA-00942 (4와 같음) |

같은 테이블인데 조회 권한이 없을 때(4)는 "존재하지 않는다", 조회 권한이 있을 때(6)는 "DELETE 권한이 누락됐다"고 나온다.

`viewer` 계정과 `emr_read` 역할은 DB에 남겨 두었다(지금은 viewer에게 역할이 없는 상태).

**해석:** 역할 emr_read를 viewer에게 주니 SELECT는 9362건이 나왔지만 DELETE는 거부됐다. 역할을 회수하니 처음처럼 조회가 안 됐다. 권한이 없을 때 Oracle은 "권한이 없다"가 아니라 "존재하지 않는다"고 말한다.
