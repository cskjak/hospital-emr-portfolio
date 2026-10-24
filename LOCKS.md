# 세션과 락(잠금) 실습

두 세션이 같은 줄을 동시에 고치려 할 때 어떤 일이 생기는지, 그리고 그 상황을 DB 안에서 어떻게 알아볼 수 있는지 확인한 기록이다.

관제 화면에서 "응답이 없다"는 상황을 만나면 먼저 장애인지, 아니면 다른 작업이 끝나기를 기다리는 중인지부터 가려야 한다. 이 실습은 그 판단 근거를 `v$session` 조회 한 번으로 찾는 연습이다.

| 단어 | 뜻 |
|---|---|
| 세션 (session) | DB 접속 하나. sqlplus 창 하나가 세션 하나다 |
| SID | 세션 번호 |
| 락 (lock) | 잠금. 한 세션이 고치고 있는 줄은 그 세션이 COMMIT이나 ROLLBACK을 하기 전까지 다른 세션이 고칠 수 없다 |
| BLOCKING_SESSION | 이 세션을 막고 있는 세션의 번호 |
| EVENT | 세션이 지금 기다리고 있는 것 |

## 1. 준비

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

## 2. 절차와 결과

### ① SID 206이 104번 줄을 고친다 (COMMIT 하지 않음)

```
SQL> UPDATE reception_copy SET status = '취소' WHERE reception_id = 104;

1 행이 업데이트되었습니다.
```

### ② SID 218이 같은 줄을 고친다 → 멈춤

```
SQL> UPDATE reception_copy SET status = '취소' WHERE reception_id = 104;
(응답 없이 멈춤)
```

같은 218 세션이 앞서 184번 줄을 고쳤을 때는 바로 `1 행이 업데이트되었습니다`가 나왔다. 명령도 세션도 같았고, 달랐던 것은 **그 줄을 다른 세션이 잡고 있었는가** 하나였다.

### ③ 관찰 창에서 세션 상태 확인

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

### ④ SID 206이 ROLLBACK → 218이 바로 진행

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

### ⑤ SID 218도 ROLLBACK → 원본과 대조

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

## 정리

| 시점 | SID 206 | SID 218 | v$session |
|---|---|---|---|
| ① | 104 UPDATE → 1행 (잠금을 잡음) | | 둘 다 INACTIVE |
| ② | 그대로 있음 | 104 UPDATE → 멈춤 | 218 ACTIVE · BLOCKING 206 · row lock contention |
| ④ | ROLLBACK | 바로 1행 업데이트 | 둘 다 INACTIVE · BLOCKING 빈칸 |
| ⑤ | | ROLLBACK | 원본 = 복사본 |

**해석:** 218은 104번 줄에서 멈췄다. 206이 그 줄을 먼저 잡고 있었기 때문이다. 이때 218은 연결된 채로 기다리는 중이었다. 막고 있던 206의 상태는 INACTIVE였다. 그래서 멈춘 세션을 보면 BLOCKING_SESSION 칸부터 확인한다. 206이 롤백하자 218의 업데이트가 진행됐고, 차단이 풀렸다.
