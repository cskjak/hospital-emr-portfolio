# 세션과 락(잠금) 실습

두 세션이 같은 줄을 동시에 고치려 할 때 어떤 일이 생기는지, 그리고 그 상황을 DB 안에서 어떻게 알아볼 수 있는지 확인한 기록이다.

관제 화면에서 "응답이 없다"는 상황을 만나면 먼저 장애인지, 아니면 다른 작업이 끝나기를 기다리는 중인지부터 가려야 한다. 이 실습은 그 판단 근거를 `v$session` 조회 한 번으로 찾는 연습이다.

| 순서 | 상황 | 상태 |
|---|---|---|
| A | 한 세션이 다른 세션을 막음 (한 방향) | ✅ |
| B | 두 세션이 서로를 막음 (데드락 · ORA-00060) | ✅ |

| 단어 | 뜻 |
|---|---|
| 세션 (session) | DB 접속 하나. sqlplus 창 하나가 세션 하나다 |
| SID | 세션 번호 |
| 락 (lock) | 잠금. 한 세션이 고치고 있는 줄은 그 세션이 COMMIT이나 ROLLBACK을 하기 전까지 다른 세션이 고칠 수 없다 |
| BLOCKING_SESSION | 이 세션을 막고 있는 세션의 번호 |
| EVENT | 세션이 지금 기다리고 있는 것 |

## A. 한 방향으로 막힘

### 1. 준비

cmd 창 3개를 띄웠다.

| 창 | 접속 | 역할 |
|---|---|---|
| 관찰 창 | `sqlplus / as sysdba` | `v$session` 조회만 한다 |
| SID 206 | emr (FREEPDB1) | 104번 줄을 먼저 고친다 |
| SID 218 | emr (FREEPDB1) | 같은 줄을 나중에 고친다 |

원본 `reception` 대신 [BACKUP.md](BACKUP.md) B에서 만든 복사본 `reception_copy`를 썼고, 고친 내용은 마지막에 모두 ROLLBACK했다.

창이 셋이면 어느 창이 어느 세션인지 헷갈리기 쉽다. 창마다 프롬프트에 이름을 붙이면 구분이 쉬워진다.

```sql
SET SQLPROMPT "창2> "
```

처음에는 관찰 창(sysdba)에서 UPDATE를 쳐서 아래 에러가 났다. 테이블 이름만 쓰면 지금 접속한 계정(SYS)의 테이블에서 찾기 때문이다. UPDATE는 emr로 접속한 창에서만 쳐야 한다.

```
ORA-00942: 테이블 또는 뷰 "SYS"."RECEPTION_COPY"이(가) 존재하지 않습니다.
```

### 2. 절차와 결과

#### ① SID 206이 104번 줄을 고친다 (COMMIT 하지 않음)

```
SQL> UPDATE reception_copy SET status = '취소' WHERE reception_id = 104;

1 행이 업데이트되었습니다.
```

#### ② SID 218이 같은 줄을 고친다 → 멈춤

```
SQL> UPDATE reception_copy SET status = '취소' WHERE reception_id = 104;
(응답 없이 멈춤)
```

같은 218 세션이 앞서 184번 줄을 고쳤을 때는 바로 `1 행이 업데이트되었습니다`가 나왔다. 명령도 세션도 같았고, 달랐던 것은 **그 줄을 다른 세션이 잡고 있었는가** 하나였다.

#### ③ 관찰 창에서 세션 상태 확인

```sql
SET LINESIZE 200
COLUMN username FORMAT A10
COLUMN event FORMAT A40
SELECT sid, username, status, blocking_session, event FROM v$session WHERE username = 'EMR';
```

```
       SID USERNAME   STATUS   BLOCKING_SESSION EVENT
---------- ---------- -------- ---------------- ----------------------------------------
       206 EMR        INACTIVE                  SQL*Net message from client
       218 EMR        ACTIVE                206 enq: TX - row lock contention
```

| SID | STATUS | BLOCKING_SESSION | EVENT | 뜻 |
|---|---|---|---|---|
| 206 | INACTIVE | (빈칸) | `SQL*Net message from client` | 다음 명령을 기다리며 쉬는 중 |
| 218 | ACTIVE | 206 | `enq: TX - row lock contention` | 206이 잡은 줄이 풀리기를 기다리는 중 |

막고 있는 206은 아무 일도 하지 않는 INACTIVE 상태였고, 막힌 218이 오히려 ACTIVE로 보였다.

#### ④ SID 206이 ROLLBACK → 218이 바로 진행

```sql
ROLLBACK;   -- SID 206 창
```

SID 218 창에 멈춰 있던 명령이 그 자리에서 끝났다.

```
1 행이 업데이트되었습니다.
```

관찰 창에서 다시 조회하니 두 세션 모두 INACTIVE로 돌아갔고, BLOCKING_SESSION 칸은 비어 있었다.

```
       SID USERNAME   STATUS   BLOCKING_SESSION EVENT
---------- ---------- -------- ---------------- ----------------------------------------
       206 EMR        INACTIVE                  SQL*Net message from client
       218 EMR        INACTIVE                  SQL*Net message from client
```

#### ⑤ SID 218도 ROLLBACK → 원본과 대조

```
SQL> ROLLBACK;

롤백이 완료되었습니다.

SQL> SELECT reception_id, status FROM reception WHERE reception_id IN (104, 184);

RECEPTION_ID STATUS
------------ --------
         104 정상
         184 정상

SQL> SELECT reception_id, status FROM reception_copy WHERE reception_id IN (104, 184);

RECEPTION_ID STATUS
------------ --------
         184 정상
         104 정상
```

218이 고친 104·184 두 줄이 함께 되돌아가, 복사본이 원본과 같아졌다. 줄 순서가 다른 것은 `ORDER BY`를 붙이지 않았기 때문이다.

### 정리

| 시점 | SID 206 | SID 218 | v$session |
|---|---|---|---|
| ① | 104 UPDATE → 1행 (잠금을 잡음) | | 둘 다 INACTIVE |
| ② | 그대로 있음 | 104 UPDATE → 멈춤 | 218 ACTIVE · BLOCKING 206 · row lock contention |
| ④ | ROLLBACK | 바로 1행 업데이트 | 둘 다 INACTIVE · BLOCKING 빈칸 |
| ⑤ | | ROLLBACK | 원본 = 복사본 |

**해석:** 218은 104번 줄에서 멈췄다. 206이 그 줄을 먼저 잡고 있었기 때문이다. 이때 218은 연결된 채로 기다리는 중이었다. 막고 있던 206의 상태는 INACTIVE였다. 그래서 멈춘 세션을 보면 BLOCKING_SESSION 칸부터 확인한다. 206이 롤백하자 218의 업데이트가 진행됐고, 차단이 풀렸다.

## B. 데드락 — 두 세션이 서로를 막을 때

A에서는 막고 있던 세션이 ROLLBACK하자 바로 풀렸다. 그런데 두 세션이 각자 줄 하나씩을 잡은 채 상대가 잡은 줄을 기다리면, 먼저 끝낼 수 있는 쪽이 없다. 이 상태를 데드락(교착 상태)이라 한다. Oracle은 이를 스스로 찾아내 한쪽의 문장 하나를 취소한다. 여기서는 그 과정을 재현하고, 흔적이 어디에 남는지 alert log와 trace 파일까지 따라가 보았다.

| 단어 | 뜻 |
|---|---|
| 데드락 (deadlock) | 두 세션이 서로 상대가 잡은 줄을 기다려서, 기다리기만 해서는 끝나지 않는 상태. 한국어 메시지로는 "교착 상태" |
| ORA-00060 | Oracle이 데드락을 찾아내 한쪽 문장을 취소할 때 내는 에러 |
| alert log | DB에 일어난 사건을 시간순으로 적어 두는 일지 |
| trace 파일 | 사건 하나의 자세한 기록. alert log에 파일 이름이 적힌다 |

### 1. 준비

[BACKUP.md](BACKUP.md) F에서 쓸 실습용 테이블스페이스 `rman_test`에 2줄짜리 테이블을 만들었다 (sysdba · FREEPDB1).

```sql
CREATE TABLE emr.dl_test (id NUMBER, val NUMBER) TABLESPACE rman_test;
INSERT INTO emr.dl_test VALUES (1, 10);
INSERT INTO emr.dl_test VALUES (2, 200);
COMMIT;
```

A에서는 창 번호와 역할이 어긋나 헷갈렸기 때문에, 이번에는 프롬프트에 역할을 그대로 적었다.

| 창 | 접속 | 프롬프트 | 역할 |
|---|---|---|---|
| 관리 창 | `sqlplus / as sysdba` → FREEPDB1 | `관리>` | `v$session` 조회 |
| SID 175 | emr | `A_1번먼저>` | 1번 줄을 먼저 잡는다 |
| SID 206 | emr | `B_2번먼저>` | 2번 줄을 먼저 잡는다 |

A의 SID 206과 여기의 SID 206은 다른 세션이다. SID는 접속할 때마다 새로 받는 번호다. A와 같은 실수(관리 창에서 UPDATE → ORA-00942 `"SYS"."DL_TEST"`)도 이번에 한 번 더 했다.

### 2. 절차와 결과

#### ①~④ 서로 엇갈려 잡기

| 순서 | 세션 | 문장 | 결과 |
|---|---|---|---|
| ① | 175 | `UPDATE dl_test SET val = val + 1 WHERE id = 1;` | 1 행이 업데이트되었습니다 (1번 줄을 잡음) |
| ② | 206 | `UPDATE dl_test SET val = val + 1 WHERE id = 2;` | 1 행이 업데이트되었습니다 (2번 줄을 잡음) |
| ③ | 175 | `UPDATE dl_test SET val = val + 1 WHERE id = 2;` | 멈춤 (206이 잡은 2번 줄을 기다림) |
| ④ | 206 | `UPDATE dl_test SET val = val + 1 WHERE id = 1;` | 멈춤 (175가 잡은 1번 줄을 기다림) |

④를 치고 잠시 뒤, 175 창에서 멈춰 있던 ③이 에러로 끝났다.

```
A_1번먼저> UPDATE dl_test SET val = val + 1 WHERE ID = 2;
1행에 오류:
ORA-00060: 자원 대기중 교착 상태가 검출되었습니다
```

#### ⑤ 관리 창에서 세션 상태 확인

```
관리> SELECT sid, blocking_session, event FROM v$session WHERE username = 'EMR';

       SID BLOCKING_SESSION EVENT
---------- ---------------- ----------------------------------------------------------------
       175                  SQL*Net message from client
       206              175 enq: TX - row lock contention
```

에러를 받은 쪽은 175인데, 막고 있는 쪽도 여전히 175였다. ORA-00060은 ③ 한 문장만 취소했고, ①로 잡은 1번 줄은 그대로 남았기 때문이다.

| 시점 | SID 175 | SID 206 | 모양 |
|---|---|---|---|
| ④ 직후 | 1번 잡음 · 2번 기다림 | 2번 잡음 · 1번 기다림 | 서로 막음 (데드락) |
| ORA-00060 뒤 | 1번 잡음 (③만 취소됨) | 2번 잡음 · 1번 기다림 | 한 방향 (A와 같은 모양) |

#### ⑥ 175 ROLLBACK → 206 진행 → 206 ROLLBACK

175 창에서 ROLLBACK을 치자, 206 창에 멈춰 있던 ④가 그 자리에서 끝났다.

```
B_2번먼저> UPDATE dl_test SET val = val + 1 WHERE id = 1;

1 행이 업데이트되었습니다.

B_2번먼저> ROLLBACK;

롤백이 완료되었습니다.
```

두 세션 모두 ROLLBACK한 뒤 관리 창에서 조회하니 값은 처음 그대로(1번 10 · 2번 200)였다.

#### ⑦ 흔적 찾기: alert log → trace 파일

alert log가 있는 폴더는 `v$diag_info`에서 찾고, 그 안의 `alert_free.log`에서 에러 번호로 줄을 찾는다.

```
관리> SELECT value FROM v$diag_info WHERE name = 'Diag Trace';
C:\APP\<사용자>\PRODUCT\26AI\diag\rdbms\free\free\trace

관리> HOST findstr /n "ORA-00060" C:\app\<사용자>\product\26ai\diag\rdbms\free\free\trace\alert_free.log
6169:FREEPDB1(3):ORA-00060: Deadlock detected. See Note 60.1 at My Oracle Support for Troubleshooting ORA-60 Errors. More info in file C:\APP\<사용자>\PRODUCT\26AI\diag\rdbms\free\free\trace\free_ora_8284.trc.
```

alert log에는 데드락이 났다는 사실과 자세한 기록이 담긴 trace 파일 이름이 한 줄로 남는다. [INCIDENTS.md](INCIDENTS.md)에서 장애 원인을 찾을 때 본 그 파일이다. trace 파일(1.6MB) 안에서 핵심은 `Deadlock graph` 부분이다.

```
Deadlock graph:
                                          ------------Blocker(s)-----------  ------------Waiter(s)------------
Resource Name                             process session holds waits serial  process session holds waits serial
TX-000A0016-00000424-DAE49D54-00000000          9     175     X        25061      83     206           X   2836
TX-00050013-000004B6-DAE49D54-00000000         83     206     X         2836       9     175           X  25061

Rows waited on:
  Session 175: obj - rowid = 00012879 - AAASh5AQAAAAAMNAAB
  (dictionary objn - 75897, file - 1024, block - 781, slot - 1)
  Session 206: obj - rowid = 00012879 - AAASh5AQAAAAAMNAAA
  (dictionary objn - 75897, file - 1024, block - 781, slot - 0)
```

한 줄이 잠금 하나다. 왼쪽(Blocker)은 잡은 세션, 오른쪽(Waiter)은 기다린 세션이다.

| 줄 | 잡은 세션 (holds) | 기다린 세션 (waits) |
|---|---|---|
| 첫째 | 175 | 206 |
| 둘째 | 206 | 175 |

①~④에서 만든 "서로 막음"을 Oracle이 그대로 적어 두었다. `Rows waited on`의 rowid가 실제로 어느 줄인지는 테이블에서 확인했다.

```
관리> SELECT ROWID, id FROM emr.dl_test;

ROWID                      ID
------------------ ----------
AAASh5AAAAAAAMNAAA          1
AAASh5AAAAAAAMNAAB          2
```

| trace | 기다린 rowid 끝 | id | 절차표 |
|---|---|---|---|
| Session 206 | `AAA` (slot 0) | 1 | ④ 206이 1번 줄을 기다림 |
| Session 175 | `AAB` (slot 1) | 2 | ③ 175가 2번 줄을 기다림 |

가운데 세 글자는 trace가 `AQA`, 조회 결과가 `AAA`로 다르다. `rman_test`는 만들 때 따로 적지 않았는데 BIGFILE 테이블스페이스로 만들어졌고(26ai 기본값), trace는 이 자리에 파일 번호 1024를 적는다(`file - 1024`). 블록(`block - 781`)과 줄(`slot`)이 같으므로 같은 줄이다.

### 정리

| 시점 | SID 175 | SID 206 | 확인한 곳 |
|---|---|---|---|
| ①② | 1번 잡음 | 2번 잡음 | |
| ③④ | 2번 기다림 | 1번 기다림 | 둘 다 멈춤 |
| 잠시 뒤 | ③ 취소 (ORA-00060) · 1번은 계속 잡음 | 1번 기다림 | `v$session` BLOCKING 175 |
| ⑥ | ROLLBACK | ④ 진행 → ROLLBACK | 값 10 · 200 그대로 |
| 사후 | | | alert log 6169번째 줄 → trace `Deadlock graph` |

**해석:** 175는 1번 줄을 잡고 2번 줄을 기다렸고, 206은 2번 줄을 잡고 1번 줄을 기다렸다. 서로를 막고 있어서 계속 돌았다. 이것이 데드락이다. ORA-00060 뒤에도 175는 1번 줄을 계속 잡고 있었고, 206은 2번 줄을 잡은 채 1번 줄을 기다렸다. 결과는 한 방향이 됐다. ORA-00060이 취소한 건 ③ 한 문장뿐이어서, ①로 잡은 1번 줄은 그대로 남았다. 데드락 흔적은 alert log에서 찾았고, 거기 적힌 trace 파일에서 자세한 내용을 봤다.
