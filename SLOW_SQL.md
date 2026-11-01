# 느린 SQL 실습 — 지금 도는 SQL을 찾아서 그것만 취소하기

관제 중에 "DB가 느리다", "화면이 멈췄다"는 연락을 받으면, 먼저 어느 세션이 어떤 SQL을 얼마나 오래 돌리고 있는지부터 확인해야 한다. 원인이 SQL 하나라면 그 SQL만 멈추면 된다.

이 실습은 일부러 끝나지 않는 SQL을 하나 돌려 두고, 다른 창에서 `v$session`과 `v$sql`로 그 SQL을 찾아낸 뒤, 그 SQL만 취소한 기록이다.

느린 SQL로는 [README.md](README.md) 25번에서 실제로 했던 실수를 다시 썼다. JOIN 줄에 `ON r.reception_id = r.reception_id`처럼 `=` 양쪽에 같은 별칭을 쓰면 모든 줄에서 참이 되어, 8,787 × 9,362 = 약 8,200만 줄이 만들어진다. 그때는 SQL이 끝나지 않아 Ctrl+C를 눌렀고, sqlplus가 통째로 꺼졌다.

| 단어 | 뜻 |
|---|---|
| `v$session` | 지금 접속해 있는 세션을 한 줄씩 보여 주는 뷰 ([LOCKS.md](LOCKS.md)에서도 썼다) |
| `v$sql` | 실행된 SQL을 문장마다 한 줄씩, 실행 횟수·걸린 시간과 함께 보여 주는 뷰 |
| STATUS | ACTIVE = 지금 SQL을 실행하는 중 · INACTIVE = 다음 명령을 기다리는 중 |
| SQL_ID | SQL 문장마다 붙는 13글자 이름표. 글자가 같은 SQL은 같은 이름표를 받는다 |
| LAST_CALL_ET | 지금 STATUS가 된 지 몇 초째인지 |
| ELAPSED_TIME | 그 SQL이 걸린 시간의 합계. 단위가 백만분의 1초라서, 1,000,000으로 나누면 초가 된다 |
| SERIAL# | SID와 함께 세션 하나를 가리키는 번호 |
| `ALTER SYSTEM CANCEL SQL` | 세션은 그대로 두고, 그 세션이 실행 중인 SQL 하나만 취소하는 명령 |

## 1. 준비

창 두 개를 띄웠다. [LOCKS.md](LOCKS.md) B처럼 프롬프트에 역할을 적어 두 창을 구분했다.

| 창 | 접속 | 프롬프트 | 역할 |
|---|---|---|---|
| 관제창 | `sqlplus / as sysdba` (CDB$ROOT) | `관제창>` | `v$session` · `v$sql` 조회와 취소 |
| SID 210 | emr (FREEPDB1) | `느린창>` | 느린 SQL 실행 |

실습을 시작할 때 FREEPDB1이 MOUNTED 상태였다. alert log에는 직전에 정상 종료한 뒤 인스턴스가 다시 시작될 때 X:의 데이터 파일을 찾지 못한 기록(ORA-01157)이 있었다. [INCIDENTS.md](INCIDENTS.md) 3번과 같은 경우라서, `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN`으로 열고 시작했다.

느린창에서는 먼저 자기 SID를 확인했다. 관제창 결과에서 어느 줄이 느린창인지 맞춰 보기 위해서다.

```
느린창> SELECT SYS_CONTEXT('USERENV', 'SID') AS 내_SID FROM dual;

내_SID
--------------------------------------------------------------------------------
210
```

느린 SQL은 아래와 같다. b 줄과 c 줄이 README 25번의 실수와 같은 모양이어서, 9,362 × 9,362 × 9,362 = 약 8,200억 줄을 세어야 한다. 끝나지 않는 것이 목적이다.

```sql
SELECT COUNT(*)
FROM reception a
JOIN reception b ON b.reception_id = b.reception_id
JOIN reception c ON c.reception_id = c.reception_id;
```

## 2. 절차와 결과

#### ① 느린 SQL을 돌리기 전 (관제창)

```
관제창> COLUMN username FORMAT A10
관제창> SELECT sid, username, status, sql_id, last_call_et
  2  FROM v$session
  3  WHERE username IS NOT NULL;

       SID USERNAME   STATUS   SQL_ID        LAST_CALL_ET
---------- ---------- -------- ------------- ------------
        48 SYS        ACTIVE   6aymzd9gamrd4            0
       210 EMR        INACTIVE 53m41vaq18qf5           56
```

SID 48은 관제창 자신이다. 이 조회를 실행하는 바로 그 순간이라 ACTIVE, 0초로 나왔다. SID 210(느린창)은 56초째 INACTIVE였다. 그런데 INACTIVE인 210에도 SQL_ID가 찍혀 있었다. 이것이 무엇인지는 ③에서 확인했다.

#### ② 느린 SQL 실행 → 다시 조회

느린창에서 위의 느린 SQL을 실행하자 화면이 멈췄다. 관제창에서 같은 조회를 `/`로 다시 실행하니 SID 210의 STATUS가 ACTIVE로 바뀌었고, SQL_ID도 다른 이름표로 바뀌었다. 이때의 화면은 남기지 않았다.

#### ③ `v$sql`로 SQL 본문 보기 (관제창)

①에서 본 SQL_ID와 ②에서 바뀐 SQL_ID를 함께 `v$sql`에서 찾으려 했다.

```
관제창> COLUMN sql_text FORMAT A60
관제창> SELECT sql_id, executions, elapsed_time, ROUND(elapsed_time/1000000) AS 걸린초, sql_text
  2  FROM v$sql
  3  WHERE sql_id IN ('53m41vaq18qf5', '▢');

SQL_ID        EXECUTIONS ELAPSED_TIME     걸린초 SQL_TEXT
------------- ---------- ------------ ---------- ------------------------------------------------------------
53m41vaq18qf5          1         7796          0 SELECT SYS_CONTEXT('USERENV', 'SID') AS 내_SID FROM dual
```

①에서 INACTIVE인 210에 남아 있던 SQL_ID는, 느린창에서 마지막으로 실행한 `내_SID` 조회였다. ELAPSED_TIME 7,796은 0.0078초다.

두 번째 자리에는 ②에서 바뀐 SQL_ID를 옮겨 넣어야 했는데, 자리 표시로 둔 `▢`를 그대로 쳤다. 그런 SQL_ID는 없으므로 에러 없이 그 줄만 빠졌다. 에러가 나지 않았다고 맞은 것은 아니라는, README에서 여러 번 확인한 경우와 같다.

그래서 SQL_ID를 손으로 옮겨 적는 대신, 두 뷰를 SQL_ID로 조인해서 한 번에 봤다.

```
관제창> SELECT s.sid, s.serial#, s.status, s.last_call_et, q.sql_id, ROUND(q.elapsed_time/1000000) AS 걸린초, Q.SQL_TEXT
  2  FROM v$session s
  3  JOIN v$sql q ON s.sql_id = q.sql_id
  4  WHERE s.username = 'EMR';

       SID    SERIAL# STATUS   LAST_CALL_ET SQL_ID            걸린초 SQL_TEXT
---------- ---------- -------- ------------ ------------- ---------- ------------------------------------------------------------
       210      42362 ACTIVE            362 6a74ak1crw0xv        362 SELECT COUNT(*) FROM reception a JOIN reception b ON b.recep
                                                                     tion_id = b.reception_id JOIN reception c ON c.reception_id
                                                                     = c.reception_id
```

SQL_TEXT에 느린창에서 친 SQL이 그대로 보였다. `v$session`의 LAST_CALL_ET(362)와 `v$sql`의 걸린초(362)도 같았다. 서로 다른 두 뷰가 같은 SQL이 돈 시간을 따로 보여 준 것이다.

#### ④ 대상을 확인하고 취소 (관제창)

취소하기 전에 대상이 맞는지 세 가지를 확인했다.

| 확인할 것 | 화면 | |
|---|---|---|
| 느린창 세션인가 | SID 210 = 느린창에서 확인한 `내_SID` 210 | ✅ |
| 지금 도는 중인가 | STATUS ACTIVE | ✅ |
| 그 SQL이 맞나 | SQL_TEXT = 느린창에서 친 `SELECT COUNT(*) …` | ✅ |

```
관제창> ALTER SYSTEM CANCEL SQL '210, 42362';

시스템이 변경되었습니다.
```

`'210, 42362'`는 SID와 SERIAL#다. SID는 세션이 끝나면 다른 세션이 다시 받을 수 있는 번호다. [LOCKS.md](LOCKS.md)의 A와 B에 나온 SID 206도 서로 다른 세션이었다. 그래서 SERIAL#까지 함께 적어야 지금 그 세션 하나로 정해진다.

관제창은 CDB$ROOT에 접속해 있었지만, FREEPDB1에 있는 세션의 SQL이 취소됐다.

#### ⑤ 느린창

```
느린창> SELECT COUNT(*)
  2  FROM reception a
  3  JOIN reception b ON b.reception_id = b.reception_id
  4  JOIN reception c ON c.reception_id = c.reception_id;
FROM reception a
     *
2행에 오류:
ORA-01013: 사용자가 현재 작업 취소를 요청했습니다. 도움말:
https://docs.oracle.com/error-help/db/ora-01013/


느린창>
```

`2행에 오류`라고 나왔지만 SQL이 틀린 것이 아니라 밖에서 취소된 것이다. 프롬프트가 다시 나왔고 창은 그대로였다. README 25번 때 Ctrl+C를 눌러 sqlplus가 통째로 꺼진 것과 다른 점이다.

#### ⑥ 취소 뒤 다시 조회 (관제창)

```
관제창> SELECT sid, username, status, sql_id, last_call_et
  2  FROM v$session
  3  WHERE username IS NOT NULL;

       SID USERNAME   STATUS   SQL_ID        LAST_CALL_ET
---------- ---------- -------- ------------- ------------
        48 SYS        ACTIVE   6aymzd9gamrd4            0
       210 EMR        INACTIVE                       3169

관제창> SELECT sql_id, executions, ROUND(elapsed_time/1000000) AS 걸린초, sql_text
  2  FROM v$sql
  3  WHERE sql_id = '6a74ak1crw0xv';

SQL_ID        EXECUTIONS     걸린초 SQL_TEXT
------------- ---------- ---------- ------------------------------------------------------------
6a74ak1crw0xv          1        475 SELECT COUNT(*) FROM reception a JOIN reception b ON b.recep
                                    tion_id = b.reception_id JOIN reception c ON c.reception_id
                                    = c.reception_id

관제창> /

SQL_ID        EXECUTIONS     걸린초 SQL_TEXT
------------- ---------- ---------- ------------------------------------------------------------
6a74ak1crw0xv          1        475 SELECT COUNT(*) FROM reception a JOIN reception b ON b.recep
                                    tion_id = b.reception_id JOIN reception c ON c.reception_id
                                    = c.reception_id
```

취소하고 약 53분 뒤에 조회했다(LAST_CALL_ET 3169초).

SID 210은 INACTIVE였고, 이번에는 SQL_ID 칸이 비어 있었다. ①에서는 INACTIVE인데도 마지막 SQL의 이름표가 남아 있었으니, INACTIVE일 때 SQL_ID 칸은 남아 있을 때도 있고 비어 있을 때도 있다. 이번에 비어 있었던 이유는 확인하지 않았다. 그래서 지금 도는 중인지는 STATUS 칸으로 판단한다.

관제창 줄의 SQL_ID `6aymzd9gamrd4`는 ①과 같았다. 같은 글자로 친 조회라서 같은 이름표를 받은 것이다.

`v$sql`에는 느린 SQL이 실행 1번, 걸린초 475로 남아 있었고, 몇 초 뒤 `/`로 다시 조회해도 475였다. 475초(7분 55초) 동안 돌다가 취소된 뒤로는 더 늘지 않았다.

### 정리

| 시점 | SID 210 (`v$session`) | `6a74ak1crw0xv` (`v$sql`) | 느린창 화면 |
|---|---|---|---|
| ① 돌리기 전 | INACTIVE · 56초째 · SQL_ID `53m41vaq18qf5` (`내_SID` 조회) | | `느린창>` |
| ③ 도는 중 | ACTIVE · 362초째 · SQL_ID `6a74ak1crw0xv` | 걸린초 362 | 멈춤 |
| ④⑤ 취소 | | | ORA-01013 → `느린창>` |
| ⑥ 취소 뒤 | INACTIVE · SQL_ID 빈칸 | 실행 1번 · 걸린초 475 (그대로) | |

`v$session`은 지금 이 순간을, `v$sql`은 SQL마다 쌓인 기록을 보여 줬다. 느린 SQL이 취소되자 `v$session`의 210 줄에서는 그 SQL_ID가 사라졌지만, `v$sql`에는 그 SQL이 얼마나 돌았는지가 남아 있었다.

**해석:** 느린 SQL은 관제창에서 보고 찾았다. v$session에서 EMR 줄의 STATUS가 활성화 상태(ACTIVE)여서 지금 도는 중인 것을 알았다. 취소한 뒤 v$session의 STATUS는 비활성화 상태(INACTIVE)로 바뀌었지만, v$sql에는 걸린초 475가 그대로 남아 있었다.
