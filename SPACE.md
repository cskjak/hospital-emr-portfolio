# 공간 실습 — 사용률(%)과 아카이브 파일

관제에서 자주 울리는 알람 중 하나가 "디스크가 찬다"는 것이다. 이 DB가 공간을 쓰는 곳은 크게 두 군데다. 테이블이 들어 있는 데이터 파일, 그리고 ARCHIVELOG 모드에서 계속 쌓이는 아카이브 파일이다. Oracle은 테이블스페이스마다 사용률(%)을 보여 주는데, 이 숫자가 무엇을 "전체"로 잡고 계산한 것인지 모르면 숫자를 잘못 읽게 된다.

이 실습은 사용률의 전체(분모)가 무엇인지 찾고, 아카이브 파일이 하나 생길 때 그 숫자들이 어떻게 움직이는지 확인한 기록이다.

| 순서 | 내용 | 상태 |
|---|---|---|
| A | 사용률(%)의 "전체"는 무엇인가 | ✅ |
| B | 아카이브 파일이 생기면 무엇이 바뀌나 | ✅ |

| 단어 | 뜻 |
|---|---|
| 테이블스페이스 (tablespace) | 테이블이 들어가는 공간. 실제로는 데이터 파일 하나 이상으로 이루어진다 |
| autoextensible | 파일이 꽉 차면 크기가 저절로 늘어나는가 (YES / NO) |
| maxbytes | 저절로 늘어날 때 끝이 되는 크기 |
| `dba_tablespace_usage_metrics` | 테이블스페이스마다 쓴 양과 사용률을 보여 주는 뷰 |
| used_space / tablespace_size | 쓴 양 / 사용률의 분모. 둘 다 블록 개수라서, 블록 1개의 크기(`db_block_size` = 8192바이트)를 곱해 MB로 바꾼다 |
| 아카이브 파일 | 다 쓴 리두 로그의 복사본. 이 DB에서는 `C:\oracle_archive`에 쌓인다 ([BACKUP.md](BACKUP.md) D) |

## A. 사용률의 "전체"는 무엇인가

### 1. 준비

sysdba로 접속한 뒤 FREEPDB1로 들어가서 조회했다.

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
SHOW CON_NAME
```

처음에는 컨테이너가 바뀌지 않은 채로 조회해서 결과에 HOSPITAL 줄이 없었다. 그때 나온 4줄의 크기(960 · 970 · 40 · 7MB)는 CDB$ROOT의 데이터 파일 크기와 같았다. 조회하기 전에 `SHOW CON_NAME`으로 FREEPDB1인지부터 확인해야 한다.

### 2. 절차와 결과

#### ① 파일 크기

```sql
SELECT tablespace_name, ROUND(bytes/1024/1024) AS 지금_MB, ROUND(maxbytes/1024/1024) AS 최대_MB, autoextensible
FROM dba_data_files;
```

```
TABLESPACE_NAME    지금_MB    최대_MB AUT
--------------- ---------- ---------- ---
SYSTEM                 310   33554432 YES
SYSAUX                 600   33554432 YES
UNDOTBS1               100   33554432 YES
USERS                    7   33554432 YES
HOSPITAL               100        500 YES
RMAN_TEST               50          0 NO
```

최대_MB 33,554,432는 32TB로, 사실상 끝이 없다는 뜻이다. HOSPITAL은 처음 만들 때 최대 500MB로 정해 두었고, RMAN_TEST는 저절로 커지지 않는 파일이다 ([BACKUP.md](BACKUP.md) F).

#### ② 사용률과 분모

```sql
SELECT tablespace_name, ROUND(used_space*8192/1024/1024, 1) AS 쓴_MB, ROUND(tablespace_size*8192/1024/1024) AS 분모_MB, ROUND(used_percent, 1) AS 사용률
FROM dba_tablespace_usage_metrics;
```

```
TABLESPACE_NAME      쓴_MB    분모_MB     사용률
--------------- ---------- ---------- ----------
SYSTEM                 309      29002        1.1
SYSAUX               539.6      29292        1.8
USERS                  6.1      28699          0
HOSPITAL                11        500        2.2
RMAN_TEST              6.1         50       12.3
TEMP                     0      28713          0
UNDOTBS1              35.4   33554432          0
```

#### ③ 분모를 ①의 크기와 맞춰 보기

| 테이블스페이스 | 저절로 커지나 | 지금_MB | 최대_MB | 분모_MB | 분모와 같은 것 |
|---|---|---|---|---|---|
| RMAN_TEST | NO | 50 | 0 | 50 | 지금 크기 |
| HOSPITAL | YES | 100 | 500 | 500 | 최대 크기 |
| SYSTEM | YES | 310 | 33,554,432 | 29,002 | 둘 다 아님 |

SYSTEM의 분모 29,002는 지금 크기도 최대 크기도 아니었다. 같은 무렵 C: 남은 공간은 28,693MB였다(PowerShell `Get-PSDrive C`). SYSTEM 파일도 C:에 있다.

```
310 (지금 크기) + 28,693 (C: 남은 공간) = 29,003  ≈  분모 29,002
```

SYSAUX(600 + 28,693 = 29,293 ≈ 29,292)와 USERS(7 + 28,693 = 28,700 ≈ 28,699)도 같은 식으로 맞았다. 1MB 차이는 반올림하거나 그사이 C:가 조금 바뀐 정도다.

HOSPITAL은 X:에 있고, X: 남은 공간은 854MB였다. 100 + 854 = 954로 최대 500보다 크기 때문에, HOSPITAL은 디스크보다 최대 크기에 먼저 닿는다. 그래서 분모가 500이다.

UNDOTBS1과 TEMP는 이번에는 보지 않았다.

### 정리

| 경우 | 예 | 사용률의 전체(분모) |
|---|---|---|
| 저절로 안 커짐 | RMAN_TEST | 지금 크기 |
| 저절로 커짐 · 최대가 디스크보다 먼저 닿음 | HOSPITAL | 최대 크기 |
| 저절로 커짐 · 최대가 사실상 없음 | SYSTEM | 지금 크기 + 디스크 남은 공간 |

**해석:** 사용률은 파일마다 달랐다. RMAN_TEST는 저절로 커지지 않아 지금 크기 50MB 중 6.1MB를 써서 사용률이 12.3%다. HOSPITAL은 저절로 커지고 최대 500MB다. 저절로 커진다는 것은 파일이 꽉 차면 크기가 늘어난다는 뜻이고, 늘어날 수 있는 끝은 HOSPITAL은 최대 500MB, SYSTEM은 C: 남은 공간(오늘 약 27.9GB)이다.

## B. 아카이브 파일이 생기면 무엇이 바뀌나

A에서 SYSTEM의 분모에 C: 남은 공간이 들어간다는 것을 알았다. 아카이브 파일도 C:에 쌓이므로, 아카이브 파일이 하나 생기면 SYSTEM의 숫자도 움직일 것이다. 이를 직접 확인했다.

### 1. 준비

실습 전 아카이브 폴더에는 30번(175.2MB)과 31번(193.3MB) 두 파일이 있었고, 지금 쓰고 있는 리두 로그는 32번이었다. `ALTER SYSTEM SWITCH LOGFILE`을 치면 32번을 닫고 다음 리두 로그로 넘어가면서, 닫힌 32번이 아카이브 폴더에 복사된다.

A가 끝나고 B를 시작할 때까지, 아카이브 파일이 생기지 않았는데도 SYSTEM 분모가 29,002에서 29,000으로 2MB 움직였다. 다른 프로그램도 C:를 조금씩 쓰기 때문이다. 그래서 아래 결과에서 몇 MB 차이는 오차로 본다.

### 2. 절차와 결과

#### ① 전 측정 (FREEPDB1)

A ②와 같은 쿼리를 다시 쳤다.

```
TABLESPACE_NAME      쓴_MB    분모_MB     사용률
--------------- ---------- ---------- ----------
SYSTEM                 309      29000        1.1
SYSAUX               541.9      29290        1.9
USERS                  6.1      28697          0
HOSPITAL                11        500        2.2
RMAN_TEST              6.1         50       12.3
TEMP                     0      28711          0
UNDOTBS1              35.4   33554432          0
```

#### ② CDB$ROOT로 옮겨 아카이브 파일 만들기

리두 로그는 DB 전체가 함께 쓰므로 CDB$ROOT로 옮겨서 쳤다.

```
SQL> ALTER SESSION SET CONTAINER = CDB$ROOT;

세션이 변경되었습니다.

SQL> ALTER SYSTEM SWITCH LOGFILE;

시스템이 변경되었습니다.
```

#### ③ 새 아카이브 파일 확인

```
SQL> SELECT sequence#, ROUND(blocks*block_size/1024/1024, 1) AS MB
  2  FROM v$archived_log WHERE deleted = 'NO' ORDER BY sequence#;

 SEQUENCE#         MB
---------- ----------
        30      175.2
        31      193.3
        32         92
```

32번 파일이 92MB로 새로 생겼다.

#### ④ FREEPDB1로 돌아와 후 측정

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
```

```
TABLESPACE_NAME      쓴_MB    분모_MB     사용률
--------------- ---------- ---------- ----------
SYSTEM                 309      28908        1.1
SYSAUX               541.9      29198        1.9
USERS                  6.1      28605          0
HOSPITAL                11        500        2.2
RMAN_TEST              6.1         50       12.3
TEMP                     0      28711          0
UNDOTBS1              35.4   33554432          0
```

실행 전 예상은 "그대로"였다. 사용률 칸을 두고 한 예상이었는데, 실제로 사용률은 그대로였고 분모는 줄었다.

### 정리

| 칸 | 전 | 후 | 차이 |
|---|---|---|---|
| 32번 아카이브 파일 | 없음 | 92MB | +92 |
| SYSTEM 분모_MB | 29,000 | 28,908 | **−92** |
| SYSAUX 분모_MB | 29,290 | 29,198 | −92 |
| USERS 분모_MB | 28,697 | 28,605 | −92 |
| SYSTEM 쓴_MB | 309 | 309 | 0 |
| SYSTEM 사용률 | 1.1 | 1.1 | 0 |
| HOSPITAL 분모_MB | 500 | 500 | 0 (X: · 최대 500) |
| RMAN_TEST 분모_MB | 50 | 50 | 0 (저절로 안 커짐) |

C:에 있고 저절로 커지는 세 테이블스페이스의 분모가 모두 아카이브 파일 크기만큼 줄었다. 파일 자체(쓴_MB)는 그대로였고, 사용률도 29,000 중 92가 너무 작아서 반올림하면 같았다. TEMP(28,711)는 C:에 있는데도 그대로였는데, 이번에는 이유를 확인하지 않았다.

32번 아카이브 파일(92MB)은 `C:\oracle_archive`에 그대로 남겨 두었다. 정리할 때는 [BACKUP.md](BACKUP.md) E의 방법(백업한 뒤 `DELETE ARCHIVELOG`)을 쓴다.

**해석:** C:에 32번 아카이브 파일(92MB)이 생기자 SYSTEM 분모는 29,000에서 28,908로 92MB 줄었지만, 사용률은 1.1 그대로였다. 관제에서는 사용률이 아니라 C: 남은 공간을 직접 봐야 한다. 사용률은 그대로여도 아카이브 파일이 쌓이면 이 값이 줄기 때문이다.
